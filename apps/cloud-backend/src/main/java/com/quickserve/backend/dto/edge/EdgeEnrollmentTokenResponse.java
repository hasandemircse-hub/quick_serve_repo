package com.quickserve.backend.dto.edge;

import lombok.Builder;
import lombok.Data;

import java.time.OffsetDateTime;

@Data
@Builder
public class EdgeEnrollmentTokenResponse {
    private Long id;
    private Long restaurantId;
    private String token;
    private Boolean isUsed;
    /** Tarayıcı/Flutter Web tarih parse sınırları için; süresiz tokenlarda true. */
    private Boolean neverExpires;
    private OffsetDateTime expiresAt;
    private OffsetDateTime usedAt;
    private OffsetDateTime createdAt;
}
