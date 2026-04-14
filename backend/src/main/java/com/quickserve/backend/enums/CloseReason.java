package com.quickserve.backend.enums;

public enum CloseReason {
    PAID_BILL,   // Hesap ödenerek kalkıldı
    NO_BILL,     // İşlemsiz kalkıldı (hiç sipariş verilmedi)
    OTHER        // Diğer şekilde kalkıldı
    // TODO(CLOSE-REASON): "Diğer şekilde kalkıldı" senaryosunu netleştir.
    // Örn: acil çıkış, kavga, vb. Garson not ekleyebilmeli mi?
}
