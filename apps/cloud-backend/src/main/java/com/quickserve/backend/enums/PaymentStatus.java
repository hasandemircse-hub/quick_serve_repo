package com.quickserve.backend.enums;

public enum PaymentStatus {
    PENDING,    // Ödeme bekleniyor
    COMPLETED,  // Ödeme tamamlandı
    FAILED,     // Ödeme başarısız
    TIMEOUT,    // POS/ödeme sonucu zaman aşımına uğradı
    REFUNDED    // İade edildi
}
