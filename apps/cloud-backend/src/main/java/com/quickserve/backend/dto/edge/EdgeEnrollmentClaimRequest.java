package com.quickserve.backend.dto.edge;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class EdgeEnrollmentClaimRequest {
    @NotBlank
    private String token;

    @NotBlank
    private String nodeName;

    private String deviceType;
    private String localIp;
}
