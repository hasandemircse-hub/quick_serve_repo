package com.quickserve.backend.dto.payment;

import com.quickserve.backend.enums.PaymentAllocationTargetType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class PaymentAllocationRequest {
    @NotNull
    private PaymentAllocationTargetType targetType;

    private Long targetId;

    @NotNull
    @DecimalMin("0.01")
    private BigDecimal amount;
}
