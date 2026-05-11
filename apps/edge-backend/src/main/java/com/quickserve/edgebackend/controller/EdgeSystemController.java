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

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;

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

    @Value("${app.edge.cloud-base-url:http://localhost:8080/api}")
    private String cloudBaseUrl;

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

    /**
     * Yerel geliştirme: cloud VM + IDE edge. Köprü JWT ile cloud uçlarının hepsine erişim dener.
     * GET http://127.0.0.1:8081/api/edge/system/cloud-probe
     */
    @GetMapping("/cloud-probe")
    public ResponseEntity<Map<String, Object>> cloudProbe() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("cloudBaseUrl", cloudBaseUrl);
        out.put("restaurantId", restaurantId);
        out.put("bridgeConfigured", cloudBridgeService.isBridgeConfigured());
        out.put("bridgeJwtShapeOk", cloudBridgeService.bridgeJwtLooksPlausible());
        if (!cloudBridgeService.isBridgeConfigured() || !cloudBridgeService.bridgeJwtLooksPlausible()) {
            out.put("todo", "Superadmin (cloud web) → Restoran Edge ayarları → 1 haftalık token → Köprü anahtarını al → .env.edge EDGE_BRIDGE_JWT_TOKEN");
            return ResponseEntity.ok(out);
        }
        out.put("snapshot", probe(() -> cloudBridgeService.fetchBootstrapSnapshot(
                restaurantId > 0 ? restaurantId : null)));
        out.put("waiterTables", probe(() -> cloudBridgeService.fetchWaiterTables()));
        out.put("waiterMenu", probe(() -> cloudBridgeService.fetchWaiterMenuFromCloud()));
        out.put("kitchenOrders", probe(() -> cloudBridgeService.fetchKitchenOrders()));
        out.put("syncEventPush", probe(() -> {
            cloudBridgeService.pushEdgeEvent(
                    "probe-" + System.currentTimeMillis(),
                    "EDGE_LOCAL_PROBE",
                    "{}");
            return "accepted";
        }));
        return ResponseEntity.ok(out);
    }

    private static String probe(Callable<?> callable) {
        try {
            Object r = callable.call();
            if (r instanceof Map<?, ?> m) {
                return "OK mapKeys=" + m.size();
            }
            if (r instanceof List<?> list) {
                return "OK listSize=" + list.size();
            }
            return r == null ? "OK" : ("OK " + r);
        } catch (Exception ex) {
            String m = ex.getMessage();
            return "FAIL " + (m == null || m.isBlank() ? ex.getClass().getSimpleName() : m);
        }
    }
}
