package com.quickserve.backend.model;

public enum TableStatus {
    EMPTY("Boş"),
    OCCUPIED("Dolu"),
    RESERVED("Rezerve");

    private final String displayName;

    TableStatus(String displayName) {
        this.displayName = displayName;
    }

    public String getDisplayName() {
        return displayName;
    }
}
