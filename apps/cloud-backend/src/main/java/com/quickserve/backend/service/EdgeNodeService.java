package com.quickserve.backend.service;

import com.quickserve.backend.dto.edge.EdgeNodeRequest;
import com.quickserve.backend.dto.edge.EdgeNodeResponse;
import com.quickserve.backend.entity.EdgeNode;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.enums.EdgeNodeStatus;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.EdgeNodeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EdgeNodeService {

    private final EdgeNodeRepository edgeNodeRepository;
    private final RestaurantService restaurantService;

    @Transactional
    public EdgeNodeResponse create(Long restaurantId, EdgeNodeRequest request) {
        Restaurant restaurant = restaurantService.findById(restaurantId);
        return toDto(edgeNodeRepository.save(buildEdgeNode(
                restaurant,
                request.getNodeName(),
                request.getDeviceType(),
                request.getLocalIp(),
                request.getStatus(),
                request.getIsActive()
        )));
    }

    @Transactional
    public EdgeNodeResponse createByEnrollment(Long restaurantId, String nodeName, String deviceType, String localIp) {
        Restaurant restaurant = restaurantService.findById(restaurantId);
        return toDto(edgeNodeRepository.save(buildEdgeNode(
                restaurant,
                nodeName,
                deviceType,
                localIp,
                EdgeNodeStatus.ONLINE,
                true
        )));
    }

    @Transactional
    public EdgeNodeResponse update(Long edgeNodeId, EdgeNodeRequest request) {
        EdgeNode edgeNode = findEntityById(edgeNodeId);
        edgeNode.setNodeName(request.getNodeName());
        if (request.getDeviceType() != null) edgeNode.setDeviceType(request.getDeviceType());
        if (request.getLocalIp() != null) edgeNode.setLocalIp(request.getLocalIp());
        if (request.getStatus() != null) edgeNode.setStatus(request.getStatus());
        if (request.getIsActive() != null) edgeNode.setIsActive(request.getIsActive());
        return toDto(edgeNodeRepository.save(edgeNode));
    }

    @Transactional(readOnly = true)
    public EdgeNodeResponse getById(Long edgeNodeId) {
        return toDto(findEntityById(edgeNodeId));
    }

    @Transactional(readOnly = true)
    public List<EdgeNodeResponse> getByRestaurantId(Long restaurantId) {
        restaurantService.findById(restaurantId);
        return edgeNodeRepository.findByRestaurantIdOrderByCreatedAtDesc(restaurantId)
                .stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public void delete(Long edgeNodeId) {
        edgeNodeRepository.delete(findEntityById(edgeNodeId));
    }

    private EdgeNode findEntityById(Long edgeNodeId) {
        return edgeNodeRepository.findById(edgeNodeId)
                .orElseThrow(() -> new ResourceNotFoundException("EdgeNode", edgeNodeId));
    }

    private EdgeNode buildEdgeNode(Restaurant restaurant,
                                   String nodeName,
                                   String deviceType,
                                   String localIp,
                                   EdgeNodeStatus status,
                                   Boolean isActive) {
        return EdgeNode.builder()
                .restaurant(restaurant)
                .nodeName(nodeName)
                .deviceType(deviceType == null ? "MINI_PC" : deviceType)
                .localIp(localIp)
                .status(status == null ? EdgeNodeStatus.OFFLINE : status)
                .isActive(isActive == null ? Boolean.TRUE : isActive)
                .build();
    }

    private EdgeNodeResponse toDto(EdgeNode edgeNode) {
        return EdgeNodeResponse.builder()
                .id(edgeNode.getId())
                .restaurantId(edgeNode.getRestaurant().getId())
                .nodeName(edgeNode.getNodeName())
                .deviceType(edgeNode.getDeviceType())
                .localIp(edgeNode.getLocalIp())
                .status(edgeNode.getStatus())
                .isActive(edgeNode.getIsActive())
                .lastSeenAt(edgeNode.getLastSeenAt())
                .createdAt(edgeNode.getCreatedAt())
                .updatedAt(edgeNode.getUpdatedAt())
                .build();
    }
}
