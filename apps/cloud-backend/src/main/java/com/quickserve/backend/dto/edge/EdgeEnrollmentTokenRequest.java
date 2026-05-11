package com.quickserve.backend.dto.edge;

import jakarta.validation.constraints.Min;
import lombok.Data;

@Data
public class EdgeEnrollmentTokenRequest {
    @Min(0)
    private Integer ttlMinutes;
}
