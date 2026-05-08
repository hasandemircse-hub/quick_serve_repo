package com.quickserve.backend.dto.feature;

import com.quickserve.backend.enums.FeatureCode;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class FeatureFlagRequest {
    @NotNull
    private FeatureCode featureCode;
    @NotNull
    private Boolean enabled;
}
