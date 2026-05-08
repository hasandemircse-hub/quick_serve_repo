package com.quickserve.backend.service;

import com.quickserve.backend.dto.report.MultiRestaurantOpsReportResponse;
import com.quickserve.backend.dto.report.RestaurantOpsSummaryResponse;
import com.quickserve.backend.entity.Order;
import com.quickserve.backend.entity.Payment;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.enums.PaymentStatus;
import com.quickserve.backend.repository.OrderRepository;
import com.quickserve.backend.repository.PaymentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class OpsReportService {

    private final RestaurantService restaurantService;
    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;

    @Transactional(readOnly = true)
    public MultiRestaurantOpsReportResponse getMultiRestaurantOpsReport(LocalDateTime from, LocalDateTime to) {
        LocalDateTime start = from != null ? from : LocalDateTime.now().minusDays(7);
        LocalDateTime end = to != null ? to : LocalDateTime.now();

        var restaurants = restaurantService.getAll();
        List<RestaurantOpsSummaryResponse> summaries = restaurants.stream()
                .map(r -> buildRestaurantSummary(r.getId(), r.getName(), start, end))
                .toList();

        long totalOrders = summaries.stream().mapToLong(s -> nullSafeLong(s.getTotalOrders())).sum();
        long totalPayments = summaries.stream().mapToLong(s -> nullSafeLong(s.getCompletedPayments())).sum();
        BigDecimal totalRevenue = summaries.stream()
                .map(s -> s.getRevenueAmount() == null ? BigDecimal.ZERO : s.getRevenueAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal totalTip = summaries.stream()
                .map(s -> s.getTipAmount() == null ? BigDecimal.ZERO : s.getTipAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        return MultiRestaurantOpsReportResponse.builder()
                .from(start)
                .to(end)
                .restaurantCount(restaurants.size())
                .totalOrders(totalOrders)
                .totalCompletedPayments(totalPayments)
                .totalRevenueAmount(totalRevenue)
                .totalTipAmount(totalTip)
                .restaurants(summaries)
                .build();
    }

    private RestaurantOpsSummaryResponse buildRestaurantSummary(Long restaurantId, String restaurantName,
                                                                LocalDateTime from, LocalDateTime to) {
        List<Order> orders = orderRepository.findByRestaurantAndDateRange(restaurantId, from, to);
        List<Payment> payments = paymentRepository.findByRestaurantIdAndCreatedAtBetween(restaurantId, from, to);

        long pending = countByOrderStatus(orders, OrderStatus.PENDING);
        long preparing = countByOrderStatus(orders, OrderStatus.PREPARING);
        long ready = countByOrderStatus(orders, OrderStatus.READY);
        long delivered = countByOrderStatus(orders, OrderStatus.DELIVERED);
        long cancelled = countByOrderStatus(orders, OrderStatus.CANCELLED);

        List<Payment> completedPayments = payments.stream()
                .filter(p -> p.getStatus() == PaymentStatus.COMPLETED)
                .toList();

        BigDecimal revenue = completedPayments.stream()
                .map(p -> p.getAmount() == null ? BigDecimal.ZERO : p.getAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal tips = completedPayments.stream()
                .map(p -> p.getTipAmount() == null ? BigDecimal.ZERO : p.getTipAmount())
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        Map<String, Long> paymentMethodCounts = new HashMap<>();
        for (Payment payment : completedPayments) {
            String key = payment.getMethod() == null ? "UNKNOWN" : payment.getMethod().name();
            paymentMethodCounts.put(key, paymentMethodCounts.getOrDefault(key, 0L) + 1);
        }

        return RestaurantOpsSummaryResponse.builder()
                .restaurantId(restaurantId)
                .restaurantName(restaurantName)
                .totalOrders((long) orders.size())
                .pendingOrders(pending)
                .preparingOrders(preparing)
                .readyOrders(ready)
                .deliveredOrders(delivered)
                .cancelledOrders(cancelled)
                .completedPayments((long) completedPayments.size())
                .revenueAmount(revenue)
                .tipAmount(tips)
                .paymentMethodCounts(paymentMethodCounts)
                .build();
    }

    private long countByOrderStatus(List<Order> orders, OrderStatus status) {
        return orders.stream().filter(o -> o.getStatus() == status).count();
    }

    private long nullSafeLong(Long value) {
        return value == null ? 0L : value;
    }
}
