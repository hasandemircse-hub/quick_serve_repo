package com.quickserve.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Cloud-only kurulumda tarayıcı {@code /edge/system/sync-status} çağırır; gerçek edge yokken
 * edge-backend ile aynı şekle yakın bir yanıt döner (UI "Sync: N/A" gösterir).
 */
@RestController
@RequestMapping("/edge/system")
public class CloudEdgeSystemController {

    @GetMapping("/sync-status")
    public ResponseEntity<Map<String, Object>> syncStatus() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("nodeId", "cloud");
        body.put("restaurantId", 0L);
        body.put("bridgeConfigured", false);
        body.put("syncLagSeconds", 0L);
        body.put("level", "UNKNOWN");
        body.put("outboxPendingCount", 0L);
        body.put("outboxRetryCount", 0L);
        body.put("outboxDeadCount", 0L);
        body.put("inboxRetryCount", 0L);
        body.put("inboxDeadCount", 0L);
        body.put("cloudOnly", true);
        return ResponseEntity.ok(body);
    }
}
