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
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.ArrayList;

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

    /** Boş snapshot (ör. bootstrap başarısız) ile cloud canlı verisini gizlememek için. */
    private static boolean snapshotHasNonEmptyTables(JsonNode root) {
        JsonNode n = root.path("tables");
        return n.isArray() && n.size() > 0;
    }

    private static boolean snapshotHasAnyMenuItems(JsonNode root) {
        JsonNode menu = root.path("menu");
        if (!menu.isObject()) {
            return false;
        }
        var it = menu.fields();
        while (it.hasNext()) {
            JsonNode arr = it.next().getValue();
            if (arr.isArray() && arr.size() > 0) {
                return true;
            }
        }
        return false;
    }

    @GetMapping("/waiter/tables")
    public ResponseEntity<List<Map<String, Object>>> getWaiterTables() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent() && snapshotHasNonEmptyTables(root.get())) {
            JsonNode tables = root.get().path("tables");
            List<Map<String, Object>> out = objectMapper.convertValue(
                    tables,
                    new TypeReference<List<Map<String, Object>>>() {});
            return ResponseEntity.ok(out);
        }
        if (cloudBridgeService.shouldTryCloudLive()) {
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
        if (root.isPresent() && snapshotHasAnyMenuItems(root.get())) {
            JsonNode menu = root.get().path("menu");
            Map<String, List<Map<String, Object>>> out = objectMapper.convertValue(
                    menu,
                    new TypeReference<Map<String, List<Map<String, Object>>>>() {});
            return ResponseEntity.ok(out);
        }
        if (cloudBridgeService.shouldTryCloudLive()) {
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

    @GetMapping("/waiter/calls")
    public ResponseEntity<List<Map<String, Object>>> getWaiterCalls() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode calls = root.get().path("pendingCalls");
            if (calls.isArray()) {
                List<Map<String, Object>> out = objectMapper.convertValue(
                        calls,
                        new TypeReference<List<Map<String, Object>>>() {});
                return ResponseEntity.ok(out);
            }
        }
        return ResponseEntity.ok(List.of());
    }

    @GetMapping("/waiter/orders")
    public ResponseEntity<List<Map<String, Object>>> getWaiterReadyOrders() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode orders = root.get().path("readyOrders");
            if (orders.isArray()) {
                List<Map<String, Object>> out = objectMapper.convertValue(
                        orders,
                        new TypeReference<List<Map<String, Object>>>() {});
                return ResponseEntity.ok(out);
            }
        }
        return ResponseEntity.ok(List.of());
    }

    @GetMapping("/admin/tables")
    public ResponseEntity<List<Map<String, Object>>> getAdminTables() {
        // Admin ekranı ilk açılışta waiter ile aynı masa listesini tüketir.
        return getWaiterTables();
    }

    @GetMapping("/admin/staff")
    public ResponseEntity<List<Map<String, Object>>> getAdminStaff() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode staff = root.get().path("staff");
            if (staff.isArray()) {
                List<Map<String, Object>> out = objectMapper.convertValue(
                        staff,
                        new TypeReference<List<Map<String, Object>>>() {});
                return ResponseEntity.ok(out);
            }
        }
        return ResponseEntity.ok(List.of());
    }

    @GetMapping("/admin/menu/categories")
    public ResponseEntity<List<Map<String, Object>>> getAdminMenuCategories() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode menu = root.get().path("menu");
            if (menu.isObject()) {
                List<Map<String, Object>> categories = new ArrayList<>();
                int order = 0;
                var fields = menu.fields();
                while (fields.hasNext()) {
                    Map.Entry<String, JsonNode> entry = fields.next();
                    String categoryName = entry.getKey();
                    JsonNode items = entry.getValue();
                    Long categoryId = null;
                    if (items.isArray() && !items.isEmpty()) {
                        JsonNode first = items.get(0);
                        JsonNode cid = first.get("categoryId");
                        if (cid != null && cid.canConvertToLong()) {
                            categoryId = cid.asLong();
                        }
                    }
                    if (categoryId == null) {
                        categoryId = (long) (order + 1);
                    }
                    Map<String, Object> cat = new LinkedHashMap<>();
                    cat.put("id", categoryId);
                    cat.put("name", categoryName);
                    cat.put("isActive", true);
                    cat.put("displayOrder", order++);
                    categories.add(cat);
                }
                return ResponseEntity.ok(categories);
            }
        }
        return ResponseEntity.ok(List.of());
    }

    @GetMapping("/admin/menu/items")
    public ResponseEntity<List<Map<String, Object>>> getAdminMenuItems() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode menu = root.get().path("menu");
            if (menu.isObject()) {
                List<Map<String, Object>> out = new ArrayList<>();
                var fields = menu.fields();
                int displayOrder = 0;
                while (fields.hasNext()) {
                    Map.Entry<String, JsonNode> entry = fields.next();
                    JsonNode items = entry.getValue();
                    if (!items.isArray()) {
                        continue;
                    }
                    for (JsonNode itemNode : items) {
                        Map<String, Object> item = objectMapper.convertValue(
                                itemNode,
                                new TypeReference<Map<String, Object>>() {});
                        if (!item.containsKey("categoryId")) {
                            Object rawId = item.get("id");
                            long fallbackCategoryId = (rawId instanceof Number n) ? n.longValue() : displayOrder + 1L;
                            item.put("categoryId", fallbackCategoryId);
                        }
                        item.putIfAbsent("isActive", true);
                        item.putIfAbsent("displayOrder", displayOrder);
                        if (!item.containsKey("effectivePrice") && item.containsKey("price")) {
                            item.put("effectivePrice", item.get("price"));
                        }
                        out.add(item);
                        displayOrder++;
                    }
                }
                return ResponseEntity.ok(out);
            }
        }
        return ResponseEntity.ok(List.of());
    }

    @GetMapping("/admin/table-groups")
    public ResponseEntity<List<Map<String, Object>>> getAdminTableGroups() {
        // Snapshot şemasında henüz table-groups yok; UI'nin ilk açılışını kırmamak için boş döneriz.
        return ResponseEntity.ok(List.of());
    }

    @GetMapping("/kitchen/orders")
    public ResponseEntity<List<Map<String, Object>>> getKitchenOrders() {
        Optional<JsonNode> root = loadSnapshotRoot();
        if (root.isPresent()) {
            JsonNode orders = root.get().path("kitchenOrders");
            if (orders.isArray() && orders.size() > 0) {
                List<Map<String, Object>> out = objectMapper.convertValue(
                        orders,
                        new TypeReference<List<Map<String, Object>>>() {});
                return ResponseEntity.ok(out);
            }
        }
        if (cloudBridgeService.shouldTryCloudLive()) {
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
