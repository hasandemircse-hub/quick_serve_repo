package com.quickserve.edgebackend.controller;

import com.quickserve.edgebackend.service.CloudBridgeService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping
public class EdgeReadController {

    private final CloudBridgeService cloudBridgeService;

    public EdgeReadController(CloudBridgeService cloudBridgeService) {
        this.cloudBridgeService = cloudBridgeService;
    }

    @GetMapping("/waiter/tables")
    public ResponseEntity<List<Map<String, Object>>> getWaiterTables() {
        if (cloudBridgeService.isBridgeConfigured()) {
            try {
                return ResponseEntity.ok(cloudBridgeService.fetchWaiterTables());
            } catch (Exception ignored) {
                // Edge-first fallback: cloud bridge unavailable olduğunda lokal mock döner.
            }
        }
        return ResponseEntity.ok(
                List.of(
                        Map.of("tableId", 1, "tableName", "Masa 1", "status", "ACTIVE"),
                        Map.of("tableId", 2, "tableName", "Masa 2", "status", "EMPTY")
                )
        );
    }

    @GetMapping("/kitchen/orders")
    public ResponseEntity<List<Map<String, Object>>> getKitchenOrders() {
        if (cloudBridgeService.isBridgeConfigured()) {
            try {
                return ResponseEntity.ok(cloudBridgeService.fetchKitchenOrders());
            } catch (Exception ignored) {
                // Edge-first fallback: cloud bridge unavailable olduğunda lokal mock döner.
            }
        }
        return ResponseEntity.ok(
                List.of(
                        Map.of("orderId", 101, "tableName", "Masa 1", "status", "PREPARING"),
                        Map.of("orderId", 102, "tableName", "Masa 4", "status", "READY")
                )
        );
    }

    @GetMapping("/admin/summary")
    public ResponseEntity<Map<String, Object>> getAdminSummary(
            @RequestParam(required = false, defaultValue = "today") String period) {
        return ResponseEntity.ok(Map.of(
                "period", period,
                "activeSessions", 3,
                "openOrders", 5,
                "pendingPayments", 2
        ));
    }
}
