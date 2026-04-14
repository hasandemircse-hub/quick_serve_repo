package com.quickserve.backend.controller;

import com.quickserve.backend.dto.order.OrderResponse;
import com.quickserve.backend.dto.payment.PaymentRequest;
import com.quickserve.backend.dto.payment.PaymentResponse;
import com.quickserve.backend.dto.table.TableResponse;
import com.quickserve.backend.entity.WaiterCall;
import com.quickserve.backend.enums.CloseReason;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/waiter")
@RequiredArgsConstructor
@Tag(name = "Waiter", description = "Garson ekranı")
public class WaiterController {

    private final TableService tableService;
    private final OrderService orderService;
    private final PaymentService paymentService;
    private final WaiterCallService waiterCallService;
    private final SecurityUtils securityUtils;

    @GetMapping("/tables")
    public ResponseEntity<List<TableResponse>> getTables() {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        return ResponseEntity.ok(tableService.getTables(restaurantId));
    }

    @GetMapping("/calls")
    public ResponseEntity<List<WaiterCall>> getPendingCalls() {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        return ResponseEntity.ok(waiterCallService.getPendingCalls(restaurantId));
    }

    @PostMapping("/calls/{callId}/assign")
    public ResponseEntity<WaiterCall> assignCall(@PathVariable Long callId) {
        Long waiterId = securityUtils.getCurrentUser().getId();
        return ResponseEntity.ok(waiterCallService.assignCall(callId, waiterId));
    }

    @PostMapping("/calls/{callId}/resolve")
    public ResponseEntity<WaiterCall> resolveCall(@PathVariable Long callId) {
        return ResponseEntity.ok(waiterCallService.resolveCall(callId));
    }

    @GetMapping("/orders")
    public ResponseEntity<List<OrderResponse>> getReadyOrders() {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        return ResponseEntity.ok(orderService.getRestaurantOrders(restaurantId, OrderStatus.READY));
    }

    @PostMapping("/orders/{orderId}/deliver")
    public ResponseEntity<OrderResponse> markDelivered(@PathVariable Long orderId) {
        return ResponseEntity.ok(orderService.updateStatus(orderId, OrderStatus.DELIVERED));
    }

    @PostMapping("/sessions/{sessionId}/close")
    public ResponseEntity<Void> closeSession(@PathVariable Long sessionId,
                                              @RequestBody Map<String, String> body) {
        CloseReason reason = CloseReason.valueOf(body.getOrDefault("reason", "OTHER"));
        Long userId = securityUtils.getCurrentUser().getId();
        tableService.closeSession(sessionId, userId, reason);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/payments/cash")
    public ResponseEntity<PaymentResponse> approveCashPayment(
            @RequestHeader("X-Session-Token") String sessionToken,
            @RequestBody PaymentRequest request) {
        Long waiterId = securityUtils.getCurrentUser().getId();
        return ResponseEntity.ok(paymentService.processCashPayment(sessionToken, request, waiterId));
    }
}
