package com.quickserve.edgebackend.device;

public record PosChargeResult(
        boolean success,
        String provider,
        String transactionId,
        String message,
        String errorCode,
        boolean retryable,
        boolean idempotentReplay
) {
    public static PosChargeResult success(String provider, String transactionId, String message) {
        return new PosChargeResult(true, provider, transactionId, message, null, false, false);
    }

    public static PosChargeResult failure(String provider, String message, String errorCode, boolean retryable) {
        return new PosChargeResult(false, provider, null, message, errorCode, retryable, false);
    }

    public PosChargeResult withIdempotentReplay() {
        return new PosChargeResult(success, provider, transactionId, message, errorCode, retryable, true);
    }
}
