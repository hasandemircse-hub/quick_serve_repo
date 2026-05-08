package com.quickserve.backend.dto.edge;

import jakarta.validation.constraints.Min;
import lombok.Data;

@Data
public class EdgeEnrollmentTokenRequest {
    @Min(1)
    private Integer ttlMinutes;
}
