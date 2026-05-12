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

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class EdgeNodeService {

    /** Edge varsayılan heartbeat 30 sn; gecikme toleransı ile çevrimdışı sayılır. */
    private static final int EFFECTIVE_ONLINE_MAX_AGE_SECONDS = 90;

    private final EdgeNodeRepository edgeNodeRepository;
    private final RestaurantService restaurantService;
    private final NotificationService notificationService;

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

    /**
     * Edge cihazından periyodik heartbeat: nodeName ile eşleşen kaydı günceller.
     * {@code lastOutboxFlushAtUtcIso} doluysa {@link EdgeNode#setLastSyncAt(LocalDateTime)} buna göre set edilir.
     */
    @Transactional
    public EdgeNodeResponse recordHeartbeat(Long restaurantId, String nodeName, String lastOutboxFlushAtUtcIso) {
        EdgeNode node = edgeNodeRepository.findFirstByRestaurant_IdAndNodeName(restaurantId, nodeName)
                .orElseThrow(() -> new ResourceNotFoundException("EdgeNode not found for restaurantId="
                        + restaurantId + " nodeName=" + nodeName));
        LocalDateTime now = LocalDateTime.now();
        node.setLastSeenAt(now);
        if (lastOutboxFlushAtUtcIso != null && !lastOutboxFlushAtUtcIso.isBlank()) {
            try {
                Instant flush = Instant.parse(lastOutboxFlushAtUtcIso.trim());
                node.setLastSyncAt(LocalDateTime.ofInstant(flush, ZoneId.systemDefault()));
            } catch (DateTimeParseException ignored) {
                // lastSyncAt değiştirme
            }
        }
        node.setStatus(EdgeNodeStatus.ONLINE);
        EdgeNode saved = edgeNodeRepository.save(node);
        EdgeNodeResponse dto = toDto(saved);
        publishNodeStatusWs(restaurantId, dto);
        return dto;
    }

    private void publishNodeStatusWs(Long restaurantId, EdgeNodeResponse dto) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("nodeName", dto.getNodeName());
        payload.put("status", dto.getStatus() != null ? dto.getStatus().name() : null);
        payload.put("lastSeenAt", dto.getLastSeenAt() != null ? dto.getLastSeenAt().toString() : null);
        payload.put("lastSyncAt", dto.getLastSyncAt() != null ? dto.getLastSyncAt().toString() : null);
        notificationService.publishToRestaurant(restaurantId, "edge_nodes", payload);
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
        LocalDateTime lastSeen = edgeNode.getLastSeenAt();
        LocalDateTime now = LocalDateTime.now();
        boolean effectiveOnline = lastSeen != null
                && ChronoUnit.SECONDS.between(lastSeen, now) <= EFFECTIVE_ONLINE_MAX_AGE_SECONDS;
        return EdgeNodeResponse.builder()
                .id(edgeNode.getId())
                .restaurantId(edgeNode.getRestaurant().getId())
                .nodeName(edgeNode.getNodeName())
                .deviceType(edgeNode.getDeviceType())
                .localIp(edgeNode.getLocalIp())
                .status(edgeNode.getStatus())
                .isActive(edgeNode.getIsActive())
                .lastSeenAt(lastSeen)
                .lastSyncAt(edgeNode.getLastSyncAt())
                .createdAt(edgeNode.getCreatedAt())
                .updatedAt(edgeNode.getUpdatedAt())
                .effectiveOnline(effectiveOnline)
                .build();
    }
}
