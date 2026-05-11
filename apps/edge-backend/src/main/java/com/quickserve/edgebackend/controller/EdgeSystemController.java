package com.quickserve.edgebackend.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.quickserve.edgebackend.service.CloudBridgeService;
import com.quickserve.edgebackend.service.EdgeBootstrapSyncService;
import com.quickserve.edgebackend.service.EdgeSyncInboxService;
import com.quickserve.edgebackend.service.EdgeSyncOutboxService;

import java.util.Map;

@RestController
@RequestMapping("/edge/system")
public class EdgeSystemController {
    private final EdgeSyncOutboxService outboxService;
    private final EdgeSyncInboxService inboxService;
    private final CloudBridgeService cloudBridgeService;
    private final EdgeBootstrapSyncService bootstrapSyncService;

    public EdgeSystemController(
            EdgeSyncOutboxService outboxService,
            EdgeSyncInboxService inboxService,
            CloudBridgeService cloudBridgeService,
            EdgeBootstrapSyncService bootstrapSyncService
    ) {
        this.outboxService = outboxService;
        this.inboxService = inboxService;
        this.cloudBridgeService = cloudBridgeService;
        this.bootstrapSyncService = bootstrapSyncService;
    }

    @Value("${app.edge.node-id:unknown}")
    private String nodeId;

    @Value("${app.edge.restaurant-id:0}")
    private long restaurantId;

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        return ResponseEntity.ok(Map.of(
                "service", "edge-backend",
                "nodeId", nodeId,
                "restaurantId", restaurantId
        ));
    }

    @GetMapping("/sync-status")
    public ResponseEntity<Map<String, Object>> syncStatus() {
        EdgeSyncOutboxService.SyncQueueStats outbox = outboxService.getQueueStats();
        EdgeSyncInboxService.InboxQueueStats inbox = inboxService.getQueueStats();
        long lagSeconds = outbox.oldestWaitingAgeSeconds() == null ? 0L : outbox.oldestWaitingAgeSeconds();
        String level = lagSeconds <= 5 ? "OK" : (lagSeconds <= 30 ? "DELAYED" : "CRITICAL");

        return ResponseEntity.ok(Map.of(
                "nodeId", nodeId,
                "restaurantId", restaurantId,
                "bridgeConfigured", cloudBridgeService.isBridgeConfigured(),
                "syncLagSeconds", lagSeconds,
                "level", level,
                "outboxPendingCount", outbox.pendingCount(),
                "outboxRetryCount", outbox.retryCount(),
                "outboxDeadCount", outbox.deadCount(),
                "inboxRetryCount", inbox.retryCount(),
                "inboxDeadCount", inbox.deadCount()
        ));
    }

    @PostMapping("/bootstrap/pull")
    public ResponseEntity<Map<String, Object>> triggerBootstrapPull() {
        boolean refreshed = bootstrapSyncService.pullSnapshotFromCloud();
        return ResponseEntity.ok(Map.of(
                "status", refreshed ? "refreshed" : "skipped_or_failed",
                "bridgeConfigured", cloudBridgeService.isBridgeConfigured(),
                "restaurantId", restaurantId
        ));
    }
}
