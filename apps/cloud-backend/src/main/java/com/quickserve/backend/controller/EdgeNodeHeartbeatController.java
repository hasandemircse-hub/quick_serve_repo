package com.quickserve.backend.controller;

import com.quickserve.backend.config.EdgeCloudLabBridge;
import com.quickserve.backend.dto.edge.EdgeHeartbeatRequest;
import com.quickserve.backend.dto.edge.EdgeNodeResponse;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.exception.UnauthorizedException;
import com.quickserve.backend.repository.RestaurantRepository;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.EdgeNodeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/edge/nodes")
@RequiredArgsConstructor
@Tag(name = "Edge nodes", description = "Edge cihaz durumu / heartbeat")
public class EdgeNodeHeartbeatController {

    private final EdgeNodeService edgeNodeService;
    private final SecurityUtils securityUtils;
    private final EdgeCloudLabBridge edgeCloudLabBridge;
    private final RestaurantRepository restaurantRepository;

    @PostMapping("/heartbeat")
    @Operation(summary = "Edge node heartbeat (lastSeenAt; isteğe bağlı lastSyncAt)")
    public ResponseEntity<EdgeNodeResponse> heartbeat(@Valid @RequestBody EdgeHeartbeatRequest request) {
        assertRestaurantAccess(request.restaurantId());
        EdgeNodeResponse dto = edgeNodeService.recordHeartbeat(
                request.restaurantId(),
                request.nodeName(),
                request.lastOutboxFlushAtUtc()
        );
        return ResponseEntity.ok(dto);
    }

    private void assertRestaurantAccess(Long restaurantId) {
        User user = securityUtils.getCurrentUserOrNull();
        if (user != null) {
            securityUtils.assertRestaurantAccess(restaurantId);
            return;
        }
        if (edgeCloudLabBridge.enabled() && restaurantId != null && restaurantId > 0) {
            if (!restaurantRepository.existsById(restaurantId)) {
                throw new UnauthorizedException("Invalid restaurantId");
            }
            return;
        }
        throw new UnauthorizedException("Authentication required");
    }
}
