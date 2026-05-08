package com.quickserve.edgebackend.device;

public class PosProviderException extends RuntimeException {
    private final String errorCode;
    private final boolean retryable;

    public PosProviderException(String errorCode, String message, boolean retryable) {
        super(message);
        this.errorCode = errorCode;
        this.retryable = retryable;
    }

    public String errorCode() {
        return errorCode;
    }

    public boolean retryable() {
        return retryable;
    }
}
