package com.quickserve.backend.dto.edge;

import jakarta.validation.constraints.Min;
import lombok.Data;

@Data
public class EdgeEnrollmentTokenRequest {
    /**
     * Geçerlilik dakika. null → 30 dk. 0 → 7 gün (eski süresiz düğmesiyle uyum).
     * Uzun süre için doğrudan 10080 (7 gün) gönderilebilir.
     */
    @Min(0)
    private Integer ttlMinutes;
}
