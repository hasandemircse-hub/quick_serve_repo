package com.quickserve.backend.model;

public enum UserRole {
    CUSTOMER("Müşteri"),
    WAITER("Garson"),
    MANAGER("Patron"),
    CHEF("Aş\u00e7\u0131"),
    ASSISTANT_CHEF("Kalfa");

    private final String displayName;

    UserRole(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
