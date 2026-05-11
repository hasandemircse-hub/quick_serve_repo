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
    private OffsetDateTime expiresAt;
    private OffsetDateTime usedAt;
    private OffsetDateTime createdAt;
}
