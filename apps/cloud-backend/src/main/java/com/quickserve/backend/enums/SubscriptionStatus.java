package com.quickserve.backend.enums;

public enum SubscriptionStatus {
    DEMO,    // Demo süresi aktif
    ACTIVE,  // Abonelik aktif ve ödenmiş
    EXPIRED, // Abonelik süresi doldu / ödeme yapılmadı
    FROZEN   // Superadmin tarafından donduruldu
}
