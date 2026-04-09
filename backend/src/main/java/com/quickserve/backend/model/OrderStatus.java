package com.quickserve.backend.model;

public enum OrderStatus {
    PENDING("Beklemede"),
    CONFIRMED("Onaylandı"),
    PREPARING("Hazırlanıyor"),
    READY("Hazır"),
    SERVED("Servis Edildi"),
    COMPLETED("Tamamlandı"),
    CANCELLED("İptal Edildi");

    private final String displayName;

    OrderStatus(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
