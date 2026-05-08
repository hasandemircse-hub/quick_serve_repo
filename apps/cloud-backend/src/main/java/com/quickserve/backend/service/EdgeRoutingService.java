package com.quickserve.backend.service;

import com.quickserve.backend.dto.edge.CustomerEdgeRouteResponse;
import com.quickserve.backend.entity.EdgeNode;
import com.quickserve.backend.entity.TableSession;
import com.quickserve.backend.enums.EdgeNodeStatus;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.repository.EdgeNodeRepository;
import com.quickserve.backend.repository.TableSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EdgeRoutingService {

    private final TableSessionRepository tableSessionRepository;
    private final EdgeNodeRepository edgeNodeRepository;

    @Value("${app.edge.customer-route-template:http://%s:8081/api}")
    private String edgeRouteTemplate;

    @Transactional(readOnly = true)
    public CustomerEdgeRouteResponse resolveBySessionToken(String sessionToken) {
        TableSession session = tableSessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new BusinessException("Geçersiz oturum token"));

        Long restaurantId = session.getRestaurantId();
        if (restaurantId == null) {
            throw new BusinessException("Oturum restoranı bulunamadı");
        }

        List<EdgeNode> edgeNodes = edgeNodeRepository
                .findByRestaurantIdAndIsActiveTrueOrderByCreatedAtDesc(restaurantId);

        EdgeNode selected = edgeNodes.stream()
                .filter(n -> n.getStatus() == EdgeNodeStatus.ONLINE && n.getLocalIp() != null && !n.getLocalIp().isBlank())
                .findFirst()
                .orElse(null);

        if (selected == null) {
            return CustomerEdgeRouteResponse.builder()
                    .restaurantId(restaurantId)
                    .edgeAvailable(false)
                    .routeMode("CLOUD_FALLBACK")
                    .build();
        }

        return CustomerEdgeRouteResponse.builder()
                .restaurantId(restaurantId)
                .edgeAvailable(true)
                .routeMode("EDGE_DIRECT")
                .edgeBaseUrl(String.format(edgeRouteTemplate, selected.getLocalIp()))
                .edgeNodeId(selected.getId())
                .edgeNodeName(selected.getNodeName())
                .build();
    }
}
