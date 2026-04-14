package com.quickserve.backend.enums;

public enum UserRole {
    SUPERADMIN,
    RESTAURANT_ADMIN,
    HEAD_WAITER,
    WAITER,
    CHEF,
    VALET    // TODO(VALE): Belge vale rolünden bahsediyor ama spesifik işlevleri net değil.
             // Şimdilik: masa durumu görme + misafir karşılama/uğurlama aksiyonu.
             // Netleştirme gerekiyor.
}
