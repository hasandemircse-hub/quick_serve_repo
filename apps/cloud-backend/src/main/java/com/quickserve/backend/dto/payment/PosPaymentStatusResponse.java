package com.quickserve.backend.dto.payment;

import com.quickserve.backend.enums.PaymentStatus;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class PosPaymentStatusResponse {
    private String posIntentId;
    private PaymentStatus status;
    private String providerRawStatus;
    private String providerTxnId;
    private String failureReason;
    private PaymentResponse payment;
}

