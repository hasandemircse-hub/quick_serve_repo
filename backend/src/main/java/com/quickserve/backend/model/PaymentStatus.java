package com.quickserve.backend.model;

public enum PaymentStatus {
    PENDING("Beklemede"),
    COMPLETED("Tamamlandı"),
    FAILED("Başarısız"),
    REFUNDED("İade Edildi");

    private final String displayName;

    PaymentStatus(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
