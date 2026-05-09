package com.quickserve.backend.controller;

import com.quickserve.backend.dto.call.WaiterCallResponse;
import com.quickserve.backend.dto.menu.MenuItemResponse;
import com.quickserve.backend.dto.order.OrderRequest;
import com.quickserve.backend.dto.order.OrderResponse;
import com.quickserve.backend.dto.payment.*;
import com.quickserve.backend.dto.table.TableResponse;
import com.quickserve.backend.enums.CloseReason;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.repository.TableSessionRepository;
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
@RequestMapping("/waiter")
@RequiredArgsConstructor
@Tag(name = "Waiter", description = "Garson ekranı")
public class WaiterController {

    private final TableService tableService;
    private final OrderService orderService;
    private final MenuService menuService;
    private final PaymentService paymentService;
    private final WaiterCallService waiterCallService;
    private final SecurityUtils securityUtils;
    private final TableSessionRepository sessionRepository;

    @GetMapping("/tables")
    public ResponseEntity<List<TableResponse>> getTables() {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        return ResponseEntity.ok(tableService.getTables(restaurantId));
    }

    @GetMapping("/menu")
    public ResponseEntity<Map<String, List<MenuItemResponse>>> getMenu() {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        return ResponseEntity.ok(menuService.getMenuGrouped(restaurantId));
    }

    @GetMapping("/calls")
    public ResponseEntity<List<WaiterCallResponse>> getPendingCalls() {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        return ResponseEntity.ok(waiterCallService.getPendingCalls(restaurantId));
    }

    @PostMapping("/calls/{callId}/assign")
    public ResponseEntity<WaiterCallResponse> assignCall(@PathVariable Long callId) {
        Long waiterId = securityUtils.getCurrentUser().getId();
        return ResponseEntity.ok(
                waiterCallService.toDto(waiterCallService.assignCall(callId, waiterId)));
    }

    @PostMapping("/calls/{callId}/resolve")
    public ResponseEntity<WaiterCallResponse> resolveCall(@PathVariable Long callId) {
        return ResponseEntity.ok(
                waiterCallService.toDto(waiterCallService.resolveCall(callId)));
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

    @PostMapping("/sessions/{sessionId}/orders")
    public ResponseEntity<OrderResponse> createOrderForSession(
            @PathVariable Long sessionId,
            @Valid @RequestBody OrderRequest request) {
        requireSessionInCurrentRestaurant(sessionId);
        return ResponseEntity.ok(orderService.createOrderForSession(sessionId, request));
    }

    @GetMapping("/sessions/{sessionId}/orders")
    public ResponseEntity<List<OrderResponse>> getSessionOrders(@PathVariable Long sessionId) {
        requireSessionInCurrentRestaurant(sessionId);
        return ResponseEntity.ok(orderService.getSessionOrdersBySessionId(sessionId));
    }

    @GetMapping("/sessions/{sessionId}/payments")
    public ResponseEntity<List<PaymentResponse>> getSessionPayments(@PathVariable Long sessionId) {
        requireSessionInCurrentRestaurant(sessionId);
        return ResponseEntity.ok(paymentService.getSessionPaymentsBySessionId(sessionId));
    }

    @GetMapping("/sessions/{sessionId}/financial-summary")
    public ResponseEntity<SessionFinancialSummaryResponse> getFinancialSummary(@PathVariable Long sessionId) {
        requireSessionInCurrentRestaurant(sessionId);
        return ResponseEntity.ok(paymentService.getSessionFinancialSummaryBySessionId(sessionId));
    }

    @PostMapping("/sessions/{sessionId}/payments/cash")
    public ResponseEntity<PaymentResponse> processSessionCashPayment(
            @PathVariable Long sessionId,
            @RequestBody PaymentRequest request) {
        requireSessionInCurrentRestaurant(sessionId);
        Long waiterId = securityUtils.getCurrentUser().getId();
        return ResponseEntity.ok(paymentService.processCashPaymentBySessionId(sessionId, request, waiterId));
    }

    @PostMapping("/sessions/{sessionId}/payments/pos/init")
    public ResponseEntity<PosPaymentStatusResponse> initSessionPosPayment(
            @PathVariable Long sessionId,
            @Valid @RequestBody PosPaymentInitRequest request) {
        requireSessionInCurrentRestaurant(sessionId);
        Long waiterId = securityUtils.getCurrentUser().getId();
        return ResponseEntity.ok(paymentService.initPosPaymentBySessionId(sessionId, request, waiterId));
    }

    @PostMapping("/sessions/{sessionId}/payments/pos/{posIntentId}/confirm")
    public ResponseEntity<PosPaymentStatusResponse> confirmSessionPosPayment(
            @PathVariable Long sessionId,
            @PathVariable String posIntentId,
            @Valid @RequestBody PosPaymentConfirmRequest request) {
        requireSessionInCurrentRestaurant(sessionId);
        return ResponseEntity.ok(paymentService.confirmPosPaymentBySessionId(sessionId, posIntentId, request));
    }

    @PostMapping("/sessions/{sessionId}/payments/pos/{posIntentId}/cancel")
    public ResponseEntity<PosPaymentStatusResponse> cancelSessionPosPayment(
            @PathVariable Long sessionId,
            @PathVariable String posIntentId,
            @RequestBody(required = false) Map<String, Object> body) {
        requireSessionInCurrentRestaurant(sessionId);
        boolean timeout = false;
        if (body != null) {
            Object raw = body.get("timeout");
            timeout = raw instanceof Boolean ? (Boolean) raw : "true".equalsIgnoreCase(String.valueOf(raw));
        }
        return ResponseEntity.ok(paymentService.cancelPosPaymentBySessionId(sessionId, posIntentId, timeout));
    }

    @GetMapping("/sessions/{sessionId}/payments/pos/{posIntentId}/status")
    public ResponseEntity<PosPaymentStatusResponse> getSessionPosPaymentStatus(
            @PathVariable Long sessionId,
            @PathVariable String posIntentId) {
        requireSessionInCurrentRestaurant(sessionId);
        return ResponseEntity.ok(paymentService.getPosPaymentStatusBySessionId(sessionId, posIntentId));
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

    private void requireSessionInCurrentRestaurant(Long sessionId) {
        Long restaurantId = securityUtils.getCurrentUser().getRestaurant().getId();
        Long sessionRestaurantId = sessionRepository.findRestaurantIdBySessionId(sessionId)
                .orElseThrow(() -> new com.quickserve.backend.exception.ResourceNotFoundException("TableSession", sessionId));
        if (!restaurantId.equals(sessionRestaurantId)) {
            throw new com.quickserve.backend.exception.UnauthorizedException("Bu oturuma erişim yetkiniz yok");
        }
    }
}
