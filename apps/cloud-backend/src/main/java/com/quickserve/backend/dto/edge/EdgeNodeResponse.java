package com.quickserve.backend.dto.edge;

import com.quickserve.backend.enums.EdgeNodeStatus;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class EdgeNodeResponse {
    private Long id;
    private Long restaurantId;
    private String nodeName;
    private String deviceType;
    private String localIp;
    private EdgeNodeStatus status;
    private Boolean isActive;
    private LocalDateTime lastSeenAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
