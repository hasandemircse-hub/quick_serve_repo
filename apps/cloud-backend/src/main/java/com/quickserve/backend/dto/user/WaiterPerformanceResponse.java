package com.quickserve.backend.dto.user;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class WaiterPerformanceResponse {
    private Long userId;
    private String fullName;
    private Long tablesServed;
    private BigDecimal totalTipsEarned;
    private Double averageRating;
    private Long totalReviews;
    private Long callsHandled;
}
