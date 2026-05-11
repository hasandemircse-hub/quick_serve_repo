package com.quickserve.backend.controller;

import com.quickserve.backend.config.EdgeCloudLabBridge;
import com.quickserve.backend.dto.edge.EdgeSyncEventRequest;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.UnauthorizedException;
import com.quickserve.backend.repository.RestaurantRepository;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.AuditService;
import com.quickserve.backend.service.EdgeSyncApplyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/edge/sync")
@RequiredArgsConstructor
@Tag(name = "Edge sync", description = "Edge node → cloud olay alımı (bridge)")
public class EdgeSyncController {

    private static final int MAX_DETAILS = 12000;

    private final AuditService auditService;
    private final SecurityUtils securityUtils;
    private final EdgeCloudLabBridge edgeCloudLabBridge;
    private final RestaurantRepository restaurantRepository;
    private final EdgeSyncApplyService edgeSyncApplyService;

    @PostMapping("/events")
    @Operation(summary = "Edge'den gelen domain olayını idempotent LWW ile uygula + audit")
    public ResponseEntity<Void> ingestEvent(
            @Valid @RequestBody EdgeSyncEventRequest request,
            HttpServletRequest httpRequest
    ) {
        User user = securityUtils.getCurrentUserOrNull();
        Long restaurantId = resolveRestaurantIdForSync(request, user);
        edgeSyncApplyService.apply(request.eventId(), request.eventType(), request.payloadJson(), restaurantId);
        if (user != null) {
            appendAudit(user.getId(), user.getUsername(), request, httpRequest, restaurantId);
        } else {
            appendAudit(null, "EDGE_LAB", request, httpRequest, restaurantId);
        }
        return ResponseEntity.accepted().build();
    }

    private Long resolveRestaurantIdForSync(EdgeSyncEventRequest request, User user) {
        if (user != null) {
            if (securityUtils.isSuperadmin()) {
                Long rid = request.restaurantId();
                if (rid == null || rid <= 0) {
                    throw new BusinessException("SUPERADMIN edge sync için restaurantId gerekli");
                }
                return rid;
            }
            Long rid = securityUtils.getCurrentRestaurantId();
            if (request.restaurantId() != null && request.restaurantId() > 0
                    && !request.restaurantId().equals(rid)) {
                throw new UnauthorizedException("restaurantId mismatch");
            }
            return rid;
        }
        Long labRid = request.restaurantId();
        if (edgeCloudLabBridge.enabled() && labRid != null && labRid > 0) {
            if (!restaurantRepository.existsById(labRid)) {
                throw new UnauthorizedException("Invalid restaurantId");
            }
            return labRid;
        }
        throw new UnauthorizedException("Authentication required");
    }

    private void appendAudit(
            Long userId,
            String actorName,
            EdgeSyncEventRequest request,
            HttpServletRequest httpRequest,
            Long restaurantId
    ) {
        String payload = request.payloadJson() == null ? "" : request.payloadJson();
        if (payload.length() > MAX_DETAILS) {
            payload = payload.substring(0, MAX_DETAILS) + "...(truncated)";
        }
        String details = "eventId=" + request.eventId()
                + " eventType=" + request.eventType()
                + " payloadJson=" + payload;
        auditService.logUserAction(
                userId,
                actorName,
                "EDGE_SYNC_EVENT",
                "EDGE_SYNC",
                null,
                details,
                clientIp(httpRequest),
                restaurantId
        );
    }

    private static String clientIp(HttpServletRequest req) {
        String forwarded = req.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return req.getRemoteAddr();
    }
}
