package com.quickserve.edgebackend.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.quickserve.edgebackend.repository.EdgeSnapshotRepository;
import com.quickserve.edgebackend.service.CloudBridgeService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping
public class EdgeReadController {

    private final CloudBridgeService cloudBridgeService;
    private final EdgeSnapshotRepository snapshotRepository;
    private final ObjectMapper objectMapper;
    private final long restaurantId;

    public EdgeReadController(
            CloudBridgeService cloudBridgeService,
            EdgeSnapshotRepository snapshotRepository,
            ObjectMapper objectMapper,
            @Value("${app.edge.restaurant-id:0}") long restaurantId
    ) {
        this.cloudBridgeService = cloudBridgeService;
        this.snapshotRepository = snapshotRepository;
        this.objectMapper = objectMapper;
        this.restaurantId = restaurantId;
    }

    private Optional<JsonNode> loadSnapshotRoot() {
        if (restaurantId <= 0) {
            return Optional.empty();
        }
        return snapshotRepository.findSnapshotPayload(restaurantId).flatMap(raw -> {
            try {
                return Optional.of(objectMapper.readTree(raw));
            } catch (Exception ignored) {
                return Optional.empty();
            }
        });
    }

    @GetMapping("/waiter/tables")
    public ResponseEntity<List<Map<String, Object>>> getWaiterTables() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode tables = root.get().path("tables");
            if (tables.isArray()) {
                List<Map<String, Object>> out = objectMapper.convertValue(
                        tables,
                        new TypeReference<List<Map<String, Object>>>() {});
                return ResponseEntity.ok(out);
            }
        }
        if (cloudBridgeService.isBridgeConfigured()) {
            try {
                return ResponseEntity.ok(cloudBridgeService.fetchWaiterTables());
            } catch (Exception ignored) {
                // fallthrough mock
            }
        }
        return ResponseEntity.ok(
                List.of(
                        Map.of("tableId", 1, "tableName", "Masa 1", "status", "ACTIVE"),
                        Map.of("tableId", 2, "tableName", "Masa 2", "status", "EMPTY")
                )
        );
    }

    @GetMapping("/waiter/menu")
    public ResponseEntity<Map<String, List<Map<String, Object>>>> getWaiterMenu() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode menu = root.get().path("menu");
            if (menu.isObject()) {
                Map<String, List<Map<String, Object>>> out = objectMapper.convertValue(
                        menu,
                        new TypeReference<Map<String, List<Map<String, Object>>>>() {});
                return ResponseEntity.ok(out);
            }
        }
        if (cloudBridgeService.isBridgeConfigured()) {
            try {
                Map<String, List<Map<String, Object>>> out = objectMapper.convertValue(
                        cloudBridgeService.fetchWaiterMenuFromCloud(),
                        new TypeReference<Map<String, List<Map<String, Object>>>>() {});
                return ResponseEntity.ok(out);
            } catch (Exception ignored) {
                // fallthrough empty
            }
        }
        return ResponseEntity.ok(Map.of());
    }

    @GetMapping("/kitchen/orders")
    public ResponseEntity<List<Map<String, Object>>> getKitchenOrders() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode orders = root.get().path("kitchenOrders");
            if (orders.isArray()) {
                List<Map<String, Object>> out = objectMapper.convertValue(
                        orders,
                        new TypeReference<List<Map<String, Object>>>() {});
                return ResponseEntity.ok(out);
            }
        }
        if (cloudBridgeService.isBridgeConfigured()) {
            try {
                return ResponseEntity.ok(cloudBridgeService.fetchKitchenOrders());
            } catch (Exception ignored) {
                // fallthrough mock
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
