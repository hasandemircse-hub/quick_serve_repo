package com.quickserve.backend.dto.report;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.Map;

@Data
@Builder
public class RestaurantOpsSummaryResponse {
    private Long restaurantId;
    private String restaurantName;
    private Long totalOrders;
    private Long pendingOrders;
    private Long preparingOrders;
    private Long readyOrders;
    private Long deliveredOrders;
    private Long cancelledOrders;
    private Long completedPayments;
    private BigDecimal revenueAmount;
    private BigDecimal tipAmount;
    private Map<String, Long> paymentMethodCounts;
}
