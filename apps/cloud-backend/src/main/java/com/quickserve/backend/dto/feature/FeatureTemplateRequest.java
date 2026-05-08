package com.quickserve.backend.dto.feature;

import com.quickserve.backend.enums.FeatureTemplate;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class FeatureTemplateRequest {
    @NotNull
    private FeatureTemplate template;
}
