package com.quickserve.backend.dto.payment;

import com.quickserve.backend.enums.PaymentAllocationTargetType;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class PaymentAllocationResponse {
    private Long id;
    private PaymentAllocationTargetType targetType;
    private Long targetId;
    private BigDecimal amount;
}
