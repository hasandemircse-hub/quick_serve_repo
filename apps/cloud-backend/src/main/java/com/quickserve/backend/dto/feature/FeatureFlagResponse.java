package com.quickserve.backend.dto.feature;

import com.quickserve.backend.enums.FeatureCode;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class FeatureFlagResponse {
    private Long id;
    private Long restaurantId;
    private FeatureCode featureCode;
    private Boolean enabled;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
