package com.quickserve.backend.controller;

import com.quickserve.backend.dto.edge.EdgeSyncEventRequest;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.AuditService;
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

    @PostMapping("/events")
    @Operation(summary = "Edge'den gelen domain olayını cloud tarafında audit'e kaydet")
    public ResponseEntity<Void> ingestEvent(
            @Valid @RequestBody EdgeSyncEventRequest request,
            HttpServletRequest httpRequest
    ) {
        User user = securityUtils.getCurrentUser();
        Long restaurantId = null;
        if (!securityUtils.isSuperadmin()) {
            restaurantId = securityUtils.getCurrentRestaurantId();
        }
        String payload = request.payloadJson() == null ? "" : request.payloadJson();
        if (payload.length() > MAX_DETAILS) {
            payload = payload.substring(0, MAX_DETAILS) + "...(truncated)";
        }
        String details = "eventId=" + request.eventId()
                + " eventType=" + request.eventType()
                + " payloadJson=" + payload;
        auditService.logUserAction(
                user.getId(),
                user.getUsername(),
                "EDGE_SYNC_EVENT",
                "EDGE_SYNC",
                null,
                details,
                clientIp(httpRequest),
                restaurantId
        );
        return ResponseEntity.accepted().build();
    }

    private static String clientIp(HttpServletRequest req) {
        String forwarded = req.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return req.getRemoteAddr();
    }
}
