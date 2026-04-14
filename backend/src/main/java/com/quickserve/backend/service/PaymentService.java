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
import com.quickserve.backend.dto.payment.PaymentRequest;
import com.quickserve.backend.dto.payment.PaymentResponse;
import com.quickserve.backend.entity.*;
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
import java.util.List;
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
    private final PaymentSplitRepository splitRepository;
    private final TableSessionRepository sessionRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final AuditService auditService;

    /**
     * Nakit veya "Diğer" ödeme - garson/kasiyer onayı ile.
     */
    @Transactional
    public PaymentResponse processCashPayment(String sessionToken, PaymentRequest request, Long approvedByUserId) {
        TableSession session = getActiveSession(sessionToken);
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
                .build();

        if (request.getPaymentSplitId() != null) {
            splitRepository.findById(request.getPaymentSplitId()).ifPresent(split -> {
                split.setIsPaid(true);
                splitRepository.save(split);
                payment.setPaymentSplit(split);
            });
        }

        Payment saved = paymentRepository.save(payment);
        notificationService.publishToRestaurant(session.getTable().getRestaurant().getId(), "payments",
                java.util.Map.of("sessionId", session.getId(), "status", "PAID"));

        return toDto(saved);
    }

    /**
     * İyzico Checkout Form başlatma.
     * Frontend bu URL'yi kullanarak İyzico'nun hosted sayfasına yönlendirir.
     */
    public String initIyzicoCheckout(String sessionToken, PaymentRequest request) {
        TableSession session = getActiveSession(sessionToken);
        Restaurant restaurant = session.getTable().getRestaurant();

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

        notificationService.publishToRestaurant(session.getTable().getRestaurant().getId(), "payments",
                java.util.Map.of("sessionId", session.getId(), "status", "PAID"));
        notificationService.publishToSession(sessionToken, "payment",
                java.util.Map.of("status", "COMPLETED"));

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
        return splits;
    }

    @Transactional(readOnly = true)
    public List<PaymentResponse> getSessionPayments(String sessionToken) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        return paymentRepository.findByTableSessionId(session.getId())
                .stream().map(this::toDto).toList();
    }

    private TableSession getActiveSession(String sessionToken) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        if (!session.getIsActive()) throw new BusinessException("Bu oturum aktif değil");
        return session;
    }

    public PaymentResponse toDto(Payment p) {
        return PaymentResponse.builder()
                .id(p.getId())
                .method(p.getMethod())
                .amount(p.getAmount())
                .tipAmount(p.getTipAmount())
                .status(p.getStatus())
                .failureReason(p.getFailureReason())
                .createdAt(p.getCreatedAt())
                .build();
    }
}
