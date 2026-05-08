package com.quickserve.backend.dto.payment;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

/**
 * Hesabı birden fazla kişi arasında bölmek için.
 * Karma ödeme destekler: her split farklı ödeme yöntemi kullanabilir.
 */
@Data
public class BillSplitRequest {
    @NotEmpty
    @Min(2)
    private Integer splitCount;
    // Eşit bölme: null ise toplam tutarı eşit böl
    // Eşit olmayan bölme: her kişi için tutar gir
    private List<SplitItem> splits;

    @Data
    public static class SplitItem {
        private String label;
        private BigDecimal amount;
    }
}
