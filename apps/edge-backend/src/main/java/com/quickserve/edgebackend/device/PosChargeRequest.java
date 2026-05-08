package com.quickserve.edgebackend.device;

import java.math.BigDecimal;

public record PosChargeRequest(
        String paymentId,
        BigDecimal amount,
        String currency,
        String orderId,
        String idempotencyKey
) {
    public PosChargeRequest(String paymentId, BigDecimal amount, String currency, String orderId) {
        this(paymentId, amount, currency, orderId, null);
    }
}
