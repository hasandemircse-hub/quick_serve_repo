package com.quickserve.backend.enums;

public enum PaymentStatus {
    PENDING,    // Ödeme bekleniyor
    COMPLETED,  // Ödeme tamamlandı
    FAILED,     // Ödeme başarısız
    REFUNDED    // İade edildi
}
