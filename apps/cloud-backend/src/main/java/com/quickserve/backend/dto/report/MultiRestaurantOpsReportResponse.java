package com.quickserve.backend.dto.report;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class MultiRestaurantOpsReportResponse {
    private LocalDateTime from;
    private LocalDateTime to;
    private Integer restaurantCount;
    private Long totalOrders;
    private Long totalCompletedPayments;
    private BigDecimal totalRevenueAmount;
    private BigDecimal totalTipAmount;
    private List<RestaurantOpsSummaryResponse> restaurants;
}
