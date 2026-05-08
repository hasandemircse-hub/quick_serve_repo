package com.quickserve.backend.dto.payment;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class PosPaymentConfirmRequest {
    @NotNull
    private Boolean success;

    private String providerTxnId;
    private String providerRef;
    private String providerRawStatus;
    private String failureReason;
}

