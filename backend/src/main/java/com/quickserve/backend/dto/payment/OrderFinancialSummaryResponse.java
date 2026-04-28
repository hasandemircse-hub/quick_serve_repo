package com.quickserve.backend.dto.payment;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class OrderFinancialSummaryResponse {
    private Long orderId;
    private String orderStatus;
    private BigDecimal totalAmount;
    private BigDecimal paidAmount;
    private BigDecimal outstandingAmount;
    private String paymentStatus;
}
