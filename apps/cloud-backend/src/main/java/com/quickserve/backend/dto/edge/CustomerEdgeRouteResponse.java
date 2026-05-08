package com.quickserve.backend.dto.edge;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class CustomerEdgeRouteResponse {
    private Long restaurantId;
    private Boolean edgeAvailable;
    private String routeMode; // EDGE_DIRECT | CLOUD_FALLBACK
    private String edgeBaseUrl;
    private Long edgeNodeId;
    private String edgeNodeName;
}
