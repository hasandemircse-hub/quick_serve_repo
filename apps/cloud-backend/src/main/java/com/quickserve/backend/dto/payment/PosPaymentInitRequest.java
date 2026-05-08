package com.quickserve.backend.dto.payment;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
public class PosPaymentInitRequest {
    @NotNull
    @DecimalMin("0.01")
    private BigDecimal amount;

    private BigDecimal tipAmount;

    private String note;

    private String terminalId;

    @NotBlank
    private String idempotencyKey;

    private List<PaymentAllocationRequest> allocations;
}

