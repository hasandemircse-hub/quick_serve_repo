package com.quickserve.backend.enums;

public enum PaymentMethod {
    CREDIT_CARD,  // İyzico kredi kartı
    DEBIT_CARD,   // İyzico banka kartı
    POS_CARD,     // Fiziksel POS/yazar kasa POS tahsilatı
    CASH,         // Nakit - garson/kasiyer onayı gerekir
    OTHER         // Diğer
}
