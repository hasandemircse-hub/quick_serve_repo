package com.quickserve.backend.controller;

import com.quickserve.backend.dto.order.OrderResponse;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.MenuService;
import com.quickserve.backend.service.OrderService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/kitchen")
@RequiredArgsConstructor
@Tag(name = "Kitchen", description = "Mutfak (Aşçı) ekranı")
public class KitchenController {

    private final OrderService orderService;
    private final MenuService menuService;
    private final SecurityUtils securityUtils;

    @GetMapping("/orders")
    public ResponseEntity<List<OrderResponse>> getKitchenOrders() {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        return ResponseEntity.ok(orderService.getKitchenOrders(restaurantId));
    }

    @PostMapping("/orders/{orderId}/start")
    public ResponseEntity<OrderResponse> startPreparing(@PathVariable Long orderId) {
        return ResponseEntity.ok(orderService.updateStatus(orderId, OrderStatus.PREPARING));
    }

    @PostMapping("/orders/{orderId}/ready")
    public ResponseEntity<OrderResponse> markReady(@PathVariable Long orderId) {
        return ResponseEntity.ok(orderService.updateStatus(orderId, OrderStatus.READY));
    }

    @PostMapping("/orders/{orderId}/priority")
    public ResponseEntity<Void> updateItemPriority(@PathVariable Long orderId,
                                                    @RequestBody List<Long> itemIdsByPriority) {
        orderService.updateItemPriority(orderId, itemIdsByPriority);
        return ResponseEntity.ok().build();
    }

    /**
     * Ürünü stokta yok olarak işaretle.
     * action: "REMOVE" (menüden kaldır) veya "UNAVAILABLE" (stokta yok uyarısı ile göster)
     */
    @PostMapping("/menu/{restaurantId}/items/{itemId}/availability")
    public ResponseEntity<Void> setAvailability(@PathVariable Long restaurantId,
                                                 @PathVariable Long itemId,
                                                 @RequestBody Map<String, String> body) {
        String action = body.getOrDefault("action", "UNAVAILABLE");
        boolean removeFromMenu = "REMOVE".equals(action);
        menuService.setAvailability(restaurantId, itemId, false, removeFromMenu);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/menu/{restaurantId}/items/{itemId}/restore")
    public ResponseEntity<Void> restoreAvailability(@PathVariable Long restaurantId,
                                                     @PathVariable Long itemId) {
        menuService.setAvailability(restaurantId, itemId, true, false);
        return ResponseEntity.ok().build();
    }
}
