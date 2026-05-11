package com.quickserve.backend.service;

import com.iyzipay.Options;
import com.iyzipay.model.Address;
import com.iyzipay.model.BasketItem;
import com.iyzipay.model.BasketItemType;
import com.iyzipay.model.Buyer;
import com.iyzipay.model.CheckoutFormInitialize;
import com.iyzipay.model.Currency;
import com.iyzipay.model.Locale;
import com.iyzipay.model.PaymentGroup;
import com.iyzipay.request.CreateCheckoutFormInitializeRequest;
import com.quickserve.backend.dto.payment.BillSplitRequest;
import com.quickserve.backend.dto.payment.OrderFinancialSummaryResponse;
import com.quickserve.backend.dto.payment.PayableItemResponse;
import com.quickserve.backend.dto.payment.PosPaymentConfirmRequest;
import com.quickserve.backend.dto.payment.PosPaymentInitRequest;
import com.quickserve.backend.dto.payment.PosPaymentStatusResponse;
import com.quickserve.backend.dto.payment.PaymentAllocationRequest;
import com.quickserve.backend.dto.payment.PaymentAllocationResponse;
import com.quickserve.backend.dto.payment.PaymentRequest;
import com.quickserve.backend.dto.payment.PaymentResponse;
import com.quickserve.backend.dto.payment.SessionFinancialSummaryResponse;
import com.quickserve.backend.entity.*;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.enums.PaymentAllocationTargetType;
import com.quickserve.backend.enums.PaymentMethod;
import com.quickserve.backend.enums.PaymentStatus;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * İyzico sanal POS entegrasyonu.
 * TODO(IYZICO): İyzico Checkout Form (hosted) yöntemi kullanılmaktadır.
 * Kart bilgileri backend'e hiç gelmez; müşteri İyzico sayfasında ödeme yapar,
 * token/callback ile sonuç buraya iletilir.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final PaymentAllocationRepository paymentAllocationRepository;
    private final PaymentSplitRepository splitRepository;
    private final TableSessionRepository sessionRepository;
    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final AuditService auditService;

    /**
     * Nakit veya "Diğer" ödeme - garson/kasiyer onayı ile.
     */
    @Transactional
    public PaymentResponse processCashPayment(String sessionToken, PaymentRequest request, Long approvedByUserId) {
        TableSession session = getActiveSession(sessionToken);
        return createManualPayment(session, request, approvedByUserId);
    }

    @Transactional
    public PaymentResponse processCashPaymentBySessionId(Long sessionId, PaymentRequest request, Long approvedByUserId) {
        TableSession session = getActiveSessionById(sessionId);
        return createManualPayment(session, request, approvedByUserId);
    }

    /**
     * POS üzerinden tahsilat başlatır. Bu adım ödeme niyetini PENDING olarak kaydeder.
     */
    @Transactional
    public PosPaymentStatusResponse initPosPaymentBySessionId(Long sessionId,
                                                              PosPaymentInitRequest request,
                                                              Long approvedByUserId) {
        TableSession session = getActiveSessionById(sessionId);
        if (!Boolean.TRUE.equals(session.getTable().getRestaurant().getIsPosDeviceEnabled())) {
            throw new BusinessException("Bu restoran için POS cihaz kullanımı kapalı");
        }

        Payment existing = paymentRepository.findByIdempotencyKey(request.getIdempotencyKey()).orElse(null);
        if (existing != null) {
            ensureSameSession(existing, sessionId);
            return toPosStatusDto(existing);
        }

        User approver = userRepository.findById(approvedByUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", approvedByUserId));

        String intentId = "pos-" + UUID.randomUUID();
        Payment payment = Payment.builder()
                .tableSession(session)
                .restaurant(session.getTable().getRestaurant())
                .method(PaymentMethod.POS_CARD)
                .amount(request.getAmount())
                .tipAmount(request.getTipAmount() != null ? request.getTipAmount() : BigDecimal.ZERO)
                .status(PaymentStatus.PENDING)
                .approvedBy(approver)
                .waiter(approver)
                .note(request.getNote() != null ? request.getNote() : "POS_PAYMENT_INTENT")
                .terminalId(request.getTerminalId())
                .idempotencyKey(request.getIdempotencyKey())
                .posIntentId(intentId)
                .providerRawStatus("INITIATED")
                .build();

        Payment saved = paymentRepository.save(payment);
        createAllocations(saved, session, request.getAllocations());
        auditService.logUserAction(
                approver.getId(),
                approver.getUsername(),
                "POS_PAYMENT_INIT",
                "PAYMENT",
                saved.getId(),
                "sessionId=" + session.getId() + ", amount=" + saved.getAmount() + ", posIntentId=" + saved.getPosIntentId(),
                null,
                session.getTable().getRestaurant().getId()
        );

        return toPosStatusDto(saved);
    }

    /**
     * POS sonucunu kesinleştirir.
     */
    @Transactional
    public PosPaymentStatusResponse confirmPosPaymentBySessionId(Long sessionId,
                                                                 String posIntentId,
                                                                 PosPaymentConfirmRequest request) {
        Payment payment = paymentRepository.findByPosIntentId(posIntentId)
                .orElseThrow(() -> new ResourceNotFoundException("POS intent bulunamadı"));
        ensureSameSession(payment, sessionId);

        if (payment.getStatus() == PaymentStatus.COMPLETED
                || payment.getStatus() == PaymentStatus.FAILED
                || payment.getStatus() == PaymentStatus.TIMEOUT) {
            return toPosStatusDto(payment);
        }

        payment.setProviderTxnId(request.getProviderTxnId());
        payment.setProviderRef(request.getProviderRef());
        payment.setProviderRawStatus(request.getProviderRawStatus());

        if (Boolean.TRUE.equals(request.getSuccess())) {
            payment.setStatus(PaymentStatus.COMPLETED);
            payment.setFailureReason(null);
            notificationService.publishToRestaurant(payment.getRestaurant().getId(), "payments",
                    java.util.Map.of("sessionId", payment.getTableSession().getId(), "status", "PAID"));
        } else {
            payment.setStatus(PaymentStatus.FAILED);
            payment.setFailureReason(request.getFailureReason() != null
                    ? request.getFailureReason() : "POS ödeme başarısız");
        }

        Payment saved = paymentRepository.save(payment);
        auditService.logUserAction(
                null,
                "POS_CONFIRM",
                "POS_PAYMENT_CONFIRM",
                "PAYMENT",
                saved.getId(),
                "sessionId=" + saved.getTableSession().getId() + ", posIntentId=" + posIntentId + ", success=" + request.getSuccess(),
                null,
                saved.getRestaurant().getId()
        );
        return toPosStatusDto(saved);
    }

    /**
     * POS bekleyen ödemeyi iptal/zaman aşımına alır.
     */
    @Transactional
    public PosPaymentStatusResponse cancelPosPaymentBySessionId(Long sessionId, String posIntentId, boolean timeout) {
        Payment payment = paymentRepository.findByPosIntentId(posIntentId)
                .orElseThrow(() -> new ResourceNotFoundException("POS intent bulunamadı"));
        ensureSameSession(payment, sessionId);

        if (payment.getStatus() == PaymentStatus.PENDING) {
            payment.setStatus(timeout ? PaymentStatus.TIMEOUT : PaymentStatus.FAILED);
            payment.setProviderRawStatus(timeout ? "TIMEOUT" : "CANCELLED");
            payment.setFailureReason(timeout ? "POS işlem zaman aşımı" : "POS işlem iptal edildi");
            paymentRepository.save(payment);
            auditService.logUserAction(
                    null,
                    "POS_CANCEL",
                    timeout ? "POS_PAYMENT_TIMEOUT" : "POS_PAYMENT_CANCEL",
                    "PAYMENT",
                    payment.getId(),
                    "sessionId=" + payment.getTableSession().getId() + ", posIntentId=" + posIntentId,
                    null,
                    payment.getRestaurant().getId()
            );
        }
        return toPosStatusDto(payment);
    }

    @Transactional(readOnly = true)
    public PosPaymentStatusResponse getPosPaymentStatusBySessionId(Long sessionId, String posIntentId) {
        Payment payment = paymentRepository.findByPosIntentId(posIntentId)
                .orElseThrow(() -> new ResourceNotFoundException("POS intent bulunamadı"));
        ensureSameSession(payment, sessionId);
        return toPosStatusDto(payment);
    }

    private PaymentResponse createManualPayment(TableSession session, PaymentRequest request, Long approvedByUserId) {
        User approver = userRepository.findById(approvedByUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", approvedByUserId));

        Payment payment = Payment.builder()
                .tableSession(session)
                .restaurant(session.getTable().getRestaurant())
                .method(request.getMethod())
                .amount(request.getAmount())
                .tipAmount(request.getTipAmount() != null ? request.getTipAmount() : BigDecimal.ZERO)
                .status(PaymentStatus.COMPLETED)
                .approvedBy(approver)
                .waiter(approver)
                .note(request.getNote())
                .build();

        if (request.getPaymentSplitId() != null) {
            splitRepository.findById(request.getPaymentSplitId()).ifPresent(split -> {
                split.setIsPaid(true);
                splitRepository.save(split);
                payment.setPaymentSplit(split);
            });
        }

        Payment saved = paymentRepository.save(payment);
        createAllocations(saved, session, request.getAllocations());
        notificationService.publishToRestaurant(session.getTable().getRestaurant().getId(), "payments",
                java.util.Map.of("sessionId", session.getId(), "status", "PAID"));
        auditService.logUserAction(
                approver.getId(),
                approver.getUsername(),
                "CASH_PAYMENT_APPROVED",
                "PAYMENT",
                saved.getId(),
                "sessionId=" + session.getId() + ", amount=" + saved.getAmount() + ", method=" + saved.getMethod(),
                null,
                session.getTable().getRestaurant().getId()
        );

        return toDto(saved);
    }

    /**
     * Müşteri tarafından (onaysız) tamamlanmış ödeme kaydı — yalnızca
     * {@code app.customer-payment-simulation-enabled=true} iken controller üzerinden çağrılmalıdır.
     * Üretimde kapalı tutulmalıdır.
     */
    @Transactional
    public PaymentResponse simulateCustomerPayment(String sessionToken, PaymentRequest request) {
        TableSession session = getActiveSession(sessionToken);

        Payment payment = Payment.builder()
                .tableSession(session)
                .restaurant(session.getTable().getRestaurant())
                .method(request.getMethod())
                .amount(request.getAmount())
                .tipAmount(request.getTipAmount() != null ? request.getTipAmount() : BigDecimal.ZERO)
                .status(PaymentStatus.COMPLETED)
                .approvedBy(null)
                .waiter(null)
                .note(request.getNote() != null ? request.getNote() : "SIMULATED_CUSTOMER_PAYMENT")
                .build();

        if (request.getPaymentSplitId() != null) {
            splitRepository.findById(request.getPaymentSplitId()).ifPresent(split -> {
                split.setIsPaid(true);
                splitRepository.save(split);
                payment.setPaymentSplit(split);
            });
        }

        Payment saved = paymentRepository.save(payment);
        createAllocations(saved, session, request.getAllocations());
        notificationService.publishToRestaurant(session.getTable().getRestaurant().getId(), "payments",
                java.util.Map.of("sessionId", session.getId(), "status", "PAID"));
        auditService.logCustomerAction(
                sessionToken,
                "CUSTOMER_PAYMENT_SIMULATED",
                "PAYMENT",
                saved.getId(),
                "sessionId=" + session.getId() + ", amount=" + saved.getAmount() + ", method=" + saved.getMethod(),
                null,
                session.getTable().getRestaurant().getId()
        );

        return toDto(saved);
    }

    /**
     * İyzico Checkout Form başlatma.
     * Frontend bu URL'yi kullanarak İyzico'nun hosted sayfasına yönlendirir.
     */
    public String initIyzicoCheckout(String sessionToken, PaymentRequest request) {
        TableSession session = getActiveSession(sessionToken);
        Restaurant restaurant = session.getTable().getRestaurant();
        // TODO(PAYMENT-ALLOCATION-FINALIZE): En kritik adım - customer kart ödemesinde
        // request.allocations bilgisi checkout intent ile kalıcı saklanmalı ve callback'te
        // COMPLETED payment kaydına birebir bağlanmalıdır. Bu yapılmadan müşteri ürün bazlı
        // kart ödemelerinin item-level finansal yansıması tam garanti edilemez.

        if (restaurant.getIyzicoApiKey() == null || restaurant.getIyzicoSecretKey() == null) {
            throw new BusinessException("Bu restoran için ödeme sistemi yapılandırılmamış");
        }

        Options options = new Options();
        options.setApiKey(restaurant.getIyzicoApiKey());
        options.setSecretKey(restaurant.getIyzicoSecretKey());
        options.setBaseUrl(restaurant.getIyzicoBaseUrl());

        CreateCheckoutFormInitializeRequest iyzicoRequest = new CreateCheckoutFormInitializeRequest();
        iyzicoRequest.setLocale(Locale.TR.getValue());
        iyzicoRequest.setConversationId(request.getConversationId() != null
                ? request.getConversationId() : UUID.randomUUID().toString());
        iyzicoRequest.setPrice(request.getAmount());
        iyzicoRequest.setPaidPrice(request.getAmount()
                .add(request.getTipAmount() != null ? request.getTipAmount() : BigDecimal.ZERO));
        iyzicoRequest.setCurrency(Currency.TRY.name());
        iyzicoRequest.setBasketId("session-" + session.getId());
        iyzicoRequest.setPaymentGroup(PaymentGroup.LISTING.name());

        // Müşteri bilgileri (zorunlu İyzico alanları)
        Buyer buyer = new Buyer();
        buyer.setId("customer-" + session.getId());
        buyer.setName("Masa");
        buyer.setSurname(session.getTable().getTableNumber());
        buyer.setEmail("customer@quickserve.com");
        buyer.setIdentityNumber("74300864791"); // TODO(IYZICO): Gerçek kimlik no alınmalı mı?
        buyer.setIp("127.0.0.1");
        buyer.setRegistrationAddress("Restoran");
        buyer.setCity("Istanbul");
        buyer.setCountry("Turkey");
        iyzicoRequest.setBuyer(buyer);

        Address address = new Address();
        address.setContactName("Masa " + session.getTable().getTableNumber());
        address.setCity("Istanbul");
        address.setCountry("Turkey");
        address.setAddress("Restoran");
        iyzicoRequest.setShippingAddress(address);
        iyzicoRequest.setBillingAddress(address);

        BasketItem basketItem = new BasketItem();
        basketItem.setId("session-" + session.getId());
        basketItem.setName("Restoran Siparisi");
        basketItem.setCategory1("Yemek");
        basketItem.setItemType(BasketItemType.VIRTUAL.name());
        basketItem.setPrice(request.getAmount());
        iyzicoRequest.setBasketItems(List.of(basketItem));

        CheckoutFormInitialize checkoutForm = CheckoutFormInitialize.create(iyzicoRequest, options);
        if (!"success".equals(checkoutForm.getStatus())) {
            log.error("İyzico checkout init failed: {}", checkoutForm.getErrorMessage());
            throw new BusinessException("Ödeme başlatılamadı: " + checkoutForm.getErrorMessage());
        }
        return checkoutForm.getPaymentPageUrl();
    }

    /**
     * İyzico callback: ödeme sonucunu kaydet.
     */
    @Transactional
    public PaymentResponse handleIyzicoCallback(String sessionToken, String iyzicoToken,
                                                  BigDecimal amount, BigDecimal tipAmount) {
        TableSession session = getActiveSession(sessionToken);
        // TODO(PAYMENT-ALLOCATION-FINALIZE): checkout intent'te saklanan allocations burada
        // resolve edilip createAllocations(saved, session, resolvedAllocations) ile yazılmalı.

        PaymentStatus status = PaymentStatus.COMPLETED;
        // Gerçek implementasyonda İyzico'dan token ile retrieve yapılır
        // TODO(IYZICO): RetrieveCheckoutForm ile token doğrulaması eklenecek

        Payment payment = Payment.builder()
                .tableSession(session)
                .restaurant(session.getTable().getRestaurant())
                .method(PaymentMethod.CREDIT_CARD)
                .amount(amount)
                .tipAmount(tipAmount != null ? tipAmount : BigDecimal.ZERO)
                .status(status)
                .iyzicoPaymentId(iyzicoToken)
                .build();
        Payment saved = paymentRepository.save(payment);
        createAllocations(saved, session, null);

        notificationService.publishToRestaurant(session.getTable().getRestaurant().getId(), "payments",
                java.util.Map.of("sessionId", session.getId(), "status", "PAID"));
        notificationService.publishToSession(sessionToken, "payment",
                java.util.Map.of("status", "COMPLETED"));
        auditService.logCustomerAction(
                sessionToken,
                "IYZICO_PAYMENT_COMPLETED",
                "PAYMENT",
                saved.getId(),
                "sessionId=" + session.getId() + ", iyzicoToken=" + iyzicoToken + ", amount=" + amount,
                null,
                session.getTable().getRestaurant().getId()
        );

        return toDto(saved);
    }

    /**
     * Hesabı böl - her kişi için PaymentSplit kaydı oluştur.
     */
    @Transactional
    public List<PaymentSplit> splitBill(String sessionToken, BillSplitRequest request) {
        TableSession session = getActiveSession(sessionToken);

        // Mevcut split'leri temizle
        List<PaymentSplit> existing = splitRepository.findByTableSessionIdAndIsPaidFalse(session.getId());
        splitRepository.deleteAll(existing);

        List<PaymentSplit> splits = new ArrayList<>();
        if (request.getSplits() != null && !request.getSplits().isEmpty()) {
            for (BillSplitRequest.SplitItem item : request.getSplits()) {
                splits.add(splitRepository.save(PaymentSplit.builder()
                        .tableSession(session)
                        .splitLabel(item.getLabel())
                        .amount(item.getAmount())
                        .isPaid(false)
                        .build()));
            }
        } else {
            // Eşit bölme: toplam tutarı hesapla
            // TODO: Toplam tutarı orderRepository'den çek
            BigDecimal total = paymentRepository.sumCompletedPaymentsForSession(session.getId());
            BigDecimal perPerson = total.divide(BigDecimal.valueOf(request.getSplitCount()),
                    2, java.math.RoundingMode.CEILING);
            for (int i = 0; i < request.getSplitCount(); i++) {
                splits.add(splitRepository.save(PaymentSplit.builder()
                        .tableSession(session)
                        .splitLabel("Kişi " + (i + 1))
                        .amount(perPerson)
                        .isPaid(false)
                        .build()));
            }
        }
        auditService.logCustomerAction(
                sessionToken,
                "BILL_SPLIT_CREATED",
                "PAYMENT_SPLIT",
                null,
                "sessionId=" + session.getId() + ", splitCount=" + splits.size(),
                null,
                session.getTable().getRestaurant().getId()
        );
        return splits;
    }

    @Transactional(readOnly = true)
    public List<PaymentResponse> getSessionPayments(String sessionToken) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        return paymentRepository.findByTableSessionId(session.getId())
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public List<PaymentResponse> getSessionPaymentsBySessionId(Long sessionId) {
        TableSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        return paymentRepository.findByTableSessionId(session.getId())
                .stream().map(this::toDto).toList();
    }

    private void createAllocations(Payment payment, TableSession session, List<PaymentAllocationRequest> requestedAllocations) {
        List<PaymentAllocationRequest> allocations = (requestedAllocations == null || requestedAllocations.isEmpty())
                ? List.of(defaultSessionAllocation(payment, session))
                : requestedAllocations;

        BigDecimal allocated = allocations.stream()
                .map(PaymentAllocationRequest::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal expected = payment.getAmount();
        if (allocated.subtract(expected).abs().compareTo(new BigDecimal("0.01")) > 0) {
            throw new BusinessException("Ödeme dağıtım toplamı ödeme tutarı ile eşleşmiyor");
        }

        List<PaymentAllocation> entities = allocations.stream()
                .map(req -> toAllocationEntity(payment, session, req))
                .toList();
        paymentAllocationRepository.saveAll(entities);
    }

    private PaymentAllocationRequest defaultSessionAllocation(Payment payment, TableSession session) {
        PaymentAllocationRequest req = new PaymentAllocationRequest();
        req.setTargetType(PaymentAllocationTargetType.SESSION);
        req.setTargetId(session.getId());
        req.setAmount(payment.getAmount());
        return req;
    }

    private PaymentAllocation toAllocationEntity(Payment payment, TableSession session, PaymentAllocationRequest req) {
        validateAllocationTarget(session, req);
        return PaymentAllocation.builder()
                .payment(payment)
                .tableSession(session)
                .targetType(req.getTargetType())
                .targetId(req.getTargetId())
                .amount(req.getAmount())
                .build();
    }

    private void validateAllocationTarget(TableSession session, PaymentAllocationRequest req) {
        if (req.getTargetType() == null) {
            throw new BusinessException("Dağıtım tipi zorunludur");
        }
        switch (req.getTargetType()) {
            case SESSION -> {
                if (req.getTargetId() != null && !req.getTargetId().equals(session.getId())) {
                    throw new BusinessException("SESSION dağıtımı bu oturuma ait olmalıdır");
                }
                req.setTargetId(session.getId());
            }
            case ORDER -> {
                if (req.getTargetId() == null) throw new BusinessException("ORDER dağıtımı için targetId zorunludur");
                Order order = orderRepository.findById(req.getTargetId())
                        .orElseThrow(() -> new ResourceNotFoundException("Order", req.getTargetId()));
                if (!order.getTableSession().getId().equals(session.getId())) {
                    throw new BusinessException("Seçilen sipariş bu masaya ait değil");
                }
            }
            case ORDER_ITEM -> {
                if (req.getTargetId() == null) throw new BusinessException("ORDER_ITEM dağıtımı için targetId zorunludur");
                OrderItem item = orderItemRepository.findById(req.getTargetId())
                        .orElseThrow(() -> new ResourceNotFoundException("OrderItem", req.getTargetId()));
                if (!item.getOrder().getTableSession().getId().equals(session.getId())) {
                    throw new BusinessException("Seçilen sipariş kalemi bu masaya ait değil");
                }
            }
        }
    }

    private PaymentDistribution calculateDistribution(List<Order> payableOrders, List<PaymentAllocation> allocations) {
        Map<Long, BigDecimal> paidByOrder = new HashMap<>();
        Map<Long, BigDecimal> paidByItem = new HashMap<>();
        Map<Long, Long> itemToOrder = new HashMap<>();
        for (Order order : payableOrders) {
            paidByOrder.put(order.getId(), BigDecimal.ZERO);
            for (OrderItem item : order.getItems()) {
                itemToOrder.put(item.getId(), order.getId());
                paidByItem.put(item.getId(), BigDecimal.ZERO);
            }
        }

        BigDecimal sessionPool = BigDecimal.ZERO;
        for (PaymentAllocation alloc : allocations) {
            if (alloc.getTargetType() == PaymentAllocationTargetType.ORDER && alloc.getTargetId() != null) {
                paidByOrder.computeIfPresent(alloc.getTargetId(), (id, paid) -> paid.add(alloc.getAmount()));
                Order order = payableOrders.stream()
                        .filter(o -> o.getId().equals(alloc.getTargetId()))
                        .findFirst().orElse(null);
                if (order != null) {
                    distributeToItems(order, paidByItem, alloc.getAmount());
                }
            } else if (alloc.getTargetType() == PaymentAllocationTargetType.ORDER_ITEM && alloc.getTargetId() != null) {
                Long orderId = itemToOrder.get(alloc.getTargetId());
                if (orderId != null) {
                    paidByOrder.computeIfPresent(orderId, (id, paid) -> paid.add(alloc.getAmount()));
                    paidByItem.computeIfPresent(alloc.getTargetId(), (id, paid) -> paid.add(alloc.getAmount()));
                }
            } else if (alloc.getTargetType() == PaymentAllocationTargetType.SESSION) {
                sessionPool = sessionPool.add(alloc.getAmount());
            }
        }

        List<Order> fifoOrders = payableOrders.stream()
                .sorted(Comparator.comparing(Order::getCreatedAt))
                .toList();
        for (Order order : fifoOrders) {
            if (sessionPool.compareTo(BigDecimal.ZERO) <= 0) break;
            BigDecimal total = order.getTotalAmount() != null ? order.getTotalAmount() : BigDecimal.ZERO;
            BigDecimal alreadyPaid = paidByOrder.getOrDefault(order.getId(), BigDecimal.ZERO);
            BigDecimal remaining = total.subtract(alreadyPaid);
            if (remaining.compareTo(BigDecimal.ZERO) <= 0) continue;

            BigDecimal applied = sessionPool.min(remaining);
            paidByOrder.put(order.getId(), alreadyPaid.add(applied));
            distributeToItems(order, paidByItem, applied);
            sessionPool = sessionPool.subtract(applied);
        }
        return new PaymentDistribution(paidByOrder, paidByItem);
    }

    private void distributeToItems(Order order, Map<Long, BigDecimal> paidByItem, BigDecimal amount) {
        if (amount.compareTo(BigDecimal.ZERO) <= 0) return;
        BigDecimal remaining = amount;
        List<OrderItem> items = new ArrayList<>(order.getItems());
        items.sort(Comparator.comparing(OrderItem::getCreatedAt));
        for (OrderItem item : items) {
            if (remaining.compareTo(BigDecimal.ZERO) <= 0) break;
            BigDecimal lineTotal = item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity()));
            BigDecimal alreadyPaid = paidByItem.getOrDefault(item.getId(), BigDecimal.ZERO);
            BigDecimal lineRemaining = lineTotal.subtract(alreadyPaid);
            if (lineRemaining.compareTo(BigDecimal.ZERO) <= 0) continue;
            BigDecimal applied = remaining.min(lineRemaining);
            paidByItem.put(item.getId(), alreadyPaid.add(applied));
            remaining = remaining.subtract(applied);
        }
    }

    private record PaymentDistribution(Map<Long, BigDecimal> paidByOrder,
                                       Map<Long, BigDecimal> paidByItem) {}

    @Transactional(readOnly = true)
    public SessionFinancialSummaryResponse getSessionFinancialSummaryBySessionId(Long sessionId) {
        TableSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));

        List<Order> orders = orderRepository.findByTableSessionIdOrderByCreatedAtDesc(session.getId());
        List<Order> payableOrders = orders.stream()
                .filter(o -> o.getStatus() != OrderStatus.CANCELLED)
                .toList();

        BigDecimal sessionTotal = payableOrders.stream()
                .map(o -> o.getTotalAmount() != null ? o.getTotalAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal paidTotal = paymentRepository.sumCompletedPaymentsForSession(session.getId());

        List<Payment> completedPayments = paymentRepository.findByTableSessionIdAndStatus(session.getId(), PaymentStatus.COMPLETED);
        List<Long> paymentIds = completedPayments.stream().map(Payment::getId).toList();
        List<PaymentAllocation> allocations = paymentIds.isEmpty()
                ? List.of()
                : paymentAllocationRepository.findByPaymentIdIn(paymentIds);

        PaymentDistribution distribution = calculateDistribution(payableOrders, allocations);
        Map<Long, BigDecimal> paidByOrder = distribution.paidByOrder();
        List<OrderFinancialSummaryResponse> orderSummaries = payableOrders.stream()
                .sorted(Comparator.comparing(Order::getCreatedAt))
                .map(order -> {
                    BigDecimal total = order.getTotalAmount() != null ? order.getTotalAmount() : BigDecimal.ZERO;
                    BigDecimal paid = paidByOrder.getOrDefault(order.getId(), BigDecimal.ZERO);
                    if (paid.compareTo(total) > 0) paid = total;
                    BigDecimal outstanding = total.subtract(paid).max(BigDecimal.ZERO);
                    String paymentStatus = paid.compareTo(BigDecimal.ZERO) == 0
                            ? "UNPAID"
                            : (outstanding.compareTo(BigDecimal.ZERO) == 0 ? "PAID" : "PARTIAL");
                    return OrderFinancialSummaryResponse.builder()
                            .orderId(order.getId())
                            .orderStatus(order.getStatus().name())
                            .totalAmount(total)
                            .paidAmount(paid)
                            .outstandingAmount(outstanding)
                            .paymentStatus(paymentStatus)
                            .build();
                })
                .toList();

        BigDecimal outstandingAmount = sessionTotal.subtract(paidTotal).max(BigDecimal.ZERO);
        BigDecimal overpaymentAmount = paidTotal.subtract(sessionTotal).max(BigDecimal.ZERO);
        return SessionFinancialSummaryResponse.builder()
                .sessionId(session.getId())
                .sessionTotal(sessionTotal)
                .paidTotal(paidTotal)
                .outstandingAmount(outstandingAmount)
                .overpaymentAmount(overpaymentAmount)
                .orders(orderSummaries)
                .build();
    }

    @Transactional(readOnly = true)
    public SessionFinancialSummaryResponse getSessionFinancialSummary(String sessionToken) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        return getSessionFinancialSummaryBySessionId(session.getId());
    }

    @Transactional(readOnly = true)
    public List<PayableItemResponse> getSessionPayableItems(String sessionToken) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));

        List<Order> orders = orderRepository.findByTableSessionIdOrderByCreatedAtDesc(session.getId());
        List<Order> payableOrders = orders.stream()
                .filter(o -> o.getStatus() != OrderStatus.CANCELLED)
                .toList();
        List<Payment> completedPayments = paymentRepository.findByTableSessionIdAndStatus(session.getId(), PaymentStatus.COMPLETED);
        List<Long> paymentIds = completedPayments.stream().map(Payment::getId).toList();
        List<PaymentAllocation> allocations = paymentIds.isEmpty()
                ? List.of()
                : paymentAllocationRepository.findByPaymentIdIn(paymentIds);
        PaymentDistribution distribution = calculateDistribution(payableOrders, allocations);

        List<PayableItemResponse> rows = new ArrayList<>();
        for (Order order : payableOrders) {
            for (OrderItem item : order.getItems()) {
                BigDecimal lineTotal = item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity()));
                BigDecimal paid = distribution.paidByItem().getOrDefault(item.getId(), BigDecimal.ZERO);
                if (paid.compareTo(lineTotal) > 0) paid = lineTotal;
                BigDecimal outstanding = lineTotal.subtract(paid).max(BigDecimal.ZERO);
                rows.add(PayableItemResponse.builder()
                        .orderId(order.getId())
                        .orderItemId(item.getId())
                        .orderStatus(order.getStatus().name())
                        .menuItemName(item.getMenuItem().getName())
                        .quantity(item.getQuantity())
                        .unitPrice(item.getUnitPrice())
                        .lineTotal(lineTotal)
                        .paidAmount(paid)
                        .outstandingAmount(outstanding)
                        .build());
            }
        }
        return rows;
    }

    /**
     * Edge bridge senkronu: ödeme tamamlandı (idempotent; zaten COMPLETED ise no-op).
     */
    @Transactional
    public void markPaymentCompletedFromEdgeBridge(Long restaurantId, Long paymentId, PaymentMethod method) {
        Payment p = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new ResourceNotFoundException("Payment", paymentId));
        if (!p.getRestaurant().getId().equals(restaurantId)) {
            throw new BusinessException("Ödeme restorana ait değil");
        }
        if (p.getStatus() == PaymentStatus.COMPLETED) {
            return;
        }
        if (p.getStatus() == PaymentStatus.REFUNDED) {
            throw new BusinessException("İade edilmiş ödeme güncellenemez");
        }
        if (method != null) {
            p.setMethod(method);
        }
        p.setStatus(PaymentStatus.COMPLETED);
        p.setProviderRawStatus("EDGE_BRIDGE_SYNC");
        paymentRepository.save(p);
    }

    private TableSession getActiveSession(String sessionToken) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        if (!session.getIsActive()) throw new BusinessException("Bu oturum aktif değil");
        return session;
    }

    private TableSession getActiveSessionById(Long sessionId) {
        TableSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        if (!session.getIsActive()) throw new BusinessException("Bu oturum aktif değil");
        return session;
    }

    private void ensureSameSession(Payment payment, Long sessionId) {
        if (!payment.getTableSession().getId().equals(sessionId)) {
            throw new BusinessException("POS işlemi bu oturuma ait değil");
        }
    }

    private PosPaymentStatusResponse toPosStatusDto(Payment payment) {
        return PosPaymentStatusResponse.builder()
                .posIntentId(payment.getPosIntentId())
                .status(payment.getStatus())
                .providerRawStatus(payment.getProviderRawStatus())
                .providerTxnId(payment.getProviderTxnId())
                .failureReason(payment.getFailureReason())
                .payment(toDto(payment))
                .build();
    }

    public PaymentResponse toDto(Payment p) {
        List<PaymentAllocationResponse> allocations = paymentAllocationRepository.findByPaymentId(p.getId())
                .stream()
                .map(a -> PaymentAllocationResponse.builder()
                        .id(a.getId())
                        .targetType(a.getTargetType())
                        .targetId(a.getTargetId())
                        .amount(a.getAmount())
                        .build())
                .toList();
        return PaymentResponse.builder()
                .id(p.getId())
                .method(p.getMethod())
                .amount(p.getAmount())
                .tipAmount(p.getTipAmount())
                .status(p.getStatus())
                .failureReason(p.getFailureReason())
                .providerTxnId(p.getProviderTxnId())
                .providerRef(p.getProviderRef())
                .terminalId(p.getTerminalId())
                .providerRawStatus(p.getProviderRawStatus())
                .posIntentId(p.getPosIntentId())
                .idempotencyKey(p.getIdempotencyKey())
                .createdAt(p.getCreatedAt())
                .allocations(allocations)
                .build();
    }
}
