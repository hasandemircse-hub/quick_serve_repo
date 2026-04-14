package com.quickserve.backend.enums;

public enum OrderStatus {
    PENDING,    // Sipariş verildi, mutfağa düştü
    PREPARING,  // Mutfak hazırlamaya başladı
    READY,      // Mutfak hazırladı, garson alacak
    DELIVERED,  // Garson masaya götürdü
    CANCELLED   // İptal edildi
}
