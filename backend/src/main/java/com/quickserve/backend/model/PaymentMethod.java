package com.quickserve.backend.model;

public enum PaymentMethod {
    CREDIT_CARD("Kredi Kartı"),
    DEBIT_CARD("Banka Kartı"),
    CASH("Nakit"),
    MOBILE_PAYMENT("Mobil Ödeme"),
    OTHER("Diğer");

    private final String displayName;

    PaymentMethod(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
