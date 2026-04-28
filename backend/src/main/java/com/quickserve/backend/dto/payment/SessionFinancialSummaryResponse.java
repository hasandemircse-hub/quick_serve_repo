package com.quickserve.backend.dto.payment;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class SessionFinancialSummaryResponse {
    private Long sessionId;
    private BigDecimal sessionTotal;
    private BigDecimal paidTotal;
    private BigDecimal outstandingAmount;
    private BigDecimal overpaymentAmount;
    private List<OrderFinancialSummaryResponse> orders;
}
