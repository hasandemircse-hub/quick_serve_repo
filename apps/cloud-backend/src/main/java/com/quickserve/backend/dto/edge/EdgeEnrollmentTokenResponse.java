package com.quickserve.backend.dto.edge;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class EdgeEnrollmentTokenResponse {
    private Long id;
    private Long restaurantId;
    private String token;
    private Boolean isUsed;
    private LocalDateTime expiresAt;
    private LocalDateTime usedAt;
    private LocalDateTime createdAt;
}
