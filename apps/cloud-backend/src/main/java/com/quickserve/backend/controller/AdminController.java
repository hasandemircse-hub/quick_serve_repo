package com.quickserve.backend.controller;

import com.quickserve.backend.dto.menu.CategoryRequest;
import com.quickserve.backend.dto.menu.MenuItemRequest;
import com.quickserve.backend.dto.menu.MenuItemResponse;
import com.quickserve.backend.dto.menu.ReorderRequest;
import com.quickserve.backend.dto.table.*;
import com.quickserve.backend.dto.user.UserRequest;
import com.quickserve.backend.dto.user.UserResponse;
import com.quickserve.backend.dto.user.WaiterPerformanceResponse;
import com.quickserve.backend.entity.MenuCategory;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/admin")
@RequiredArgsConstructor
@Tag(name = "Admin", description = "Restoran admin ekranı")
public class AdminController {

    private final TableService tableService;
    private final TableGroupService tableGroupService;
    private final MenuService menuService;
    private final StaffService staffService;
    private final OrderService orderService;
    private final ReviewService reviewService;
    private final SecurityUtils securityUtils;

    private Long restaurantId() {
        return securityUtils.getCurrentRestaurantId();
    }

    // ──── Masa Yönetimi ──────────────────────────────────────────────────────

    @GetMapping("/tables")
    public ResponseEntity<List<TableResponse>> getTables() {
        return ResponseEntity.ok(tableService.getTables(restaurantId()));
    }

    @PostMapping("/tables")
    public ResponseEntity<TableResponse> createTable(@Valid @RequestBody TableRequest request) {
        return ResponseEntity.ok(tableService.createTable(restaurantId(), request));
    }

    @PutMapping("/tables/{tableId}")
    public ResponseEntity<TableResponse> updateTable(@PathVariable Long tableId,
                                                      @Valid @RequestBody TableRequest request) {
        return ResponseEntity.ok(tableService.updateTable(tableId, request));
    }

    @PutMapping("/tables/layout")
    public ResponseEntity<Void> updateLayout(@Valid @RequestBody TableLayoutUpdateRequest request) {
        tableService.updateLayout(restaurantId(), request);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/tables/{tableId}")
    public ResponseEntity<Void> deleteTable(@PathVariable Long tableId) {
        tableService.deleteTable(tableId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/tables/{tableId}/regenerate-qr")
    public ResponseEntity<Void> regenerateQr(@PathVariable Long tableId) {
        tableService.regenerateQr(tableId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/tables/{tableId}/undo-regenerate-qr")
    public ResponseEntity<Void> undoRegenerateQr(@PathVariable Long tableId) {
        tableService.undoRegenerateQr(tableId);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/tables/{tableId}/qr")
    public ResponseEntity<byte[]> getQrImage(@PathVariable Long tableId) {
        byte[] bytes = tableService.getQrImage(tableId);
        return ResponseEntity.ok()
                .header("Content-Type", "image/png")
                .body(bytes);
    }

    // ──── Masa Grupları ──────────────────────────────────────────────────────

    @GetMapping("/table-groups")
    public ResponseEntity<List<TableGroupResponse>> getTableGroups() {
        return ResponseEntity.ok(tableGroupService.getGroups(restaurantId()));
    }

    @PostMapping("/table-groups")
    public ResponseEntity<TableGroupResponse> createTableGroup(@Valid @RequestBody TableGroupRequest request) {
        return ResponseEntity.ok(tableGroupService.createGroup(restaurantId(), request));
    }

    @PutMapping("/table-groups/{groupId}")
    public ResponseEntity<TableGroupResponse> updateTableGroup(@PathVariable Long groupId,
                                                                @Valid @RequestBody TableGroupRequest request) {
        return ResponseEntity.ok(tableGroupService.updateGroup(restaurantId(), groupId, request));
    }

    @DeleteMapping("/table-groups/{groupId}")
    public ResponseEntity<Void> deleteTableGroup(@PathVariable Long groupId) {
        tableGroupService.deleteGroup(restaurantId(), groupId);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/table-groups/reorder")
    public ResponseEntity<Void> reorderTableGroups(@RequestBody List<ReorderRequest> items) {
        tableGroupService.reorder(restaurantId(), items);
        return ResponseEntity.ok().build();
    }

    // ──── Menü Yönetimi ──────────────────────────────────────────────────────

    @GetMapping("/menu/categories")
    public ResponseEntity<List<MenuCategory>> getCategories() {
        return ResponseEntity.ok(menuService.getCategories(restaurantId(), false));
    }

    @PostMapping("/menu/categories")
    public ResponseEntity<MenuCategory> createCategory(@Valid @RequestBody CategoryRequest request) {
        return ResponseEntity.ok(menuService.createCategory(restaurantId(), request));
    }

    @PutMapping("/menu/categories/{categoryId}")
    public ResponseEntity<MenuCategory> updateCategory(@PathVariable Long categoryId,
                                                        @Valid @RequestBody CategoryRequest request) {
        return ResponseEntity.ok(menuService.updateCategory(restaurantId(), categoryId, request));
    }

    @PutMapping("/menu/categories/reorder")
    public ResponseEntity<Void> reorderCategories(@RequestBody List<ReorderRequest> items) {
        menuService.reorderCategories(restaurantId(), items);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/menu/items/reorder")
    public ResponseEntity<Void> reorderItems(@RequestBody List<ReorderRequest> items) {
        menuService.reorderItems(restaurantId(), items);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/menu/categories/{categoryId}")
    public ResponseEntity<Void> deleteCategory(@PathVariable Long categoryId) {
        menuService.deleteCategory(restaurantId(), categoryId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/menu/items")
    public ResponseEntity<List<MenuItemResponse>> getItems() {
        return ResponseEntity.ok(menuService.getAllItems(restaurantId()));
    }

    @PostMapping("/menu/items")
    public ResponseEntity<MenuItemResponse> createItem(@Valid @RequestBody MenuItemRequest request) {
        return ResponseEntity.ok(menuService.createItem(restaurantId(), request));
    }

    @PutMapping("/menu/items/{itemId}")
    public ResponseEntity<MenuItemResponse> updateItem(@PathVariable Long itemId,
                                                        @Valid @RequestBody MenuItemRequest request) {
        return ResponseEntity.ok(menuService.updateItem(restaurantId(), itemId, request));
    }

    @DeleteMapping("/menu/items/{itemId}")
    public ResponseEntity<Void> deleteItem(@PathVariable Long itemId) {
        menuService.deleteItem(restaurantId(), itemId);
        return ResponseEntity.noContent().build();
    }

    // ──── Personel Yönetimi ──────────────────────────────────────────────────

    @GetMapping("/staff")
    public ResponseEntity<List<UserResponse>> getStaff() {
        return ResponseEntity.ok(staffService.getStaff(restaurantId()));
    }

    @PostMapping("/staff")
    public ResponseEntity<UserResponse> createStaff(@Valid @RequestBody UserRequest request) {
        return ResponseEntity.ok(staffService.createStaff(restaurantId(), request));
    }

    @PutMapping("/staff/{userId}")
    public ResponseEntity<UserResponse> updateStaff(@PathVariable Long userId,
                                                     @Valid @RequestBody UserRequest request) {
        return ResponseEntity.ok(staffService.updateStaff(userId, request));
    }

    @PostMapping("/staff/{userId}/leave")
    public ResponseEntity<Void> setLeave(@PathVariable Long userId,
                                          @RequestBody Map<String, String> body) {
        boolean onLeave = Boolean.parseBoolean(body.get("onLeave"));
        staffService.setLeave(userId, onLeave, body.get("reason"));
        return ResponseEntity.ok().build();
    }

    @PostMapping("/staff/{userId}/active")
    public ResponseEntity<Void> setActive(@PathVariable Long userId,
                                           @RequestBody Map<String, Boolean> body) {
        staffService.setActive(userId, body.get("active"));
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/staff/{userId}")
    public ResponseEntity<Void> deleteStaff(@PathVariable Long userId) {
        staffService.deleteStaff(userId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/staff/{userId}/performance")
    public ResponseEntity<WaiterPerformanceResponse> getWaiterPerformance(@PathVariable Long userId) {
        return ResponseEntity.ok(staffService.getWaiterPerformance(userId));
    }

    // ──── Operasyon Takibi ───────────────────────────────────────────────────

    @GetMapping("/reviews")
    public ResponseEntity<?> getReviews() {
        return ResponseEntity.ok(reviewService.getRestaurantReviews(restaurantId()));
    }
}
