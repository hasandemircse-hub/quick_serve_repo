package com.quickserve.backend.dto.edge;

import com.quickserve.backend.enums.EdgeNodeStatus;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class EdgeNodeRequest {
    @NotBlank
    private String nodeName;
    private String deviceType;
    private String localIp;
    private EdgeNodeStatus status;
    private Boolean isActive;
}
