package com.quickserve.edgebackend.controller;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.quickserve.edgebackend.service.EdgeSyncOutboxService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping
public class EdgeOpsController {

    private final EdgeSyncOutboxService outboxService;
    private final ObjectMapper objectMapper;

    public EdgeOpsController(EdgeSyncOutboxService outboxService, ObjectMapper objectMapper) {
        this.outboxService = outboxService;
        this.objectMapper = objectMapper;
    }

    @GetMapping("/waiter/ping")
    public ResponseEntity<Map<String, Object>> waiterPing() {
        return ResponseEntity.ok(Map.of("service", "edge-backend", "domain", "waiter", "status", "ok"));
    }

    @GetMapping("/kitchen/ping")
    public ResponseEntity<Map<String, Object>> kitchenPing() {
        return ResponseEntity.ok(Map.of("service", "edge-backend", "domain", "kitchen", "status", "ok"));
    }

    @GetMapping("/admin/ping")
    public ResponseEntity<Map<String, Object>> adminPing() {
        return ResponseEntity.ok(Map.of("service", "edge-backend", "domain", "admin", "status", "ok"));
    }

    @PostMapping("/waiter/orders")
    public ResponseEntity<Map<String, Object>> createWaiterOrder(@Valid @RequestBody CreateOrderRequest request) {
        String orderId = UUID.randomUUID().toString();
        enqueueDomainEvent("ORDER", orderId, "ORDER_CREATED", Map.of(
                "orderId", orderId,
                "tableId", request.tableId(),
                "note", safe(request.note()),
                "source", "EDGE_WAITER"
        ));
        return ResponseEntity.ok(Map.of("status", "accepted", "orderId", orderId));
    }

    @PostMapping("/kitchen/orders/status")
    public ResponseEntity<Map<String, Object>> updateKitchenOrderStatus(@Valid @RequestBody KitchenStatusUpdateRequest request) {
        enqueueDomainEvent("ORDER", request.orderId(), "ORDER_STATUS_UPDATED", Map.of(
                "orderId", request.orderId(),
                "status", request.status(),
                "source", "EDGE_KITCHEN"
        ));
        return ResponseEntity.ok(Map.of("status", "accepted", "orderId", request.orderId()));
    }

    @PostMapping("/admin/payments/mark-paid")
    public ResponseEntity<Map<String, Object>> markPaymentPaid(@Valid @RequestBody MarkPaidRequest request) {
        enqueueDomainEvent("PAYMENT", request.paymentId(), "PAYMENT_MARKED_PAID", Map.of(
                "paymentId", request.paymentId(),
                "method", request.method(),
                "source", "EDGE_ADMIN"
        ));
        return ResponseEntity.ok(Map.of("status", "accepted", "paymentId", request.paymentId()));
    }

    @PostMapping("/waiter/calls/{callId}/assign")
    public ResponseEntity<Map<String, Object>> assignWaiterCall(@PathVariable String callId) {
        enqueueDomainEvent("CALL", callId, "CALL_ASSIGNED", Map.of(
                "callId", callId,
                "source", "EDGE_WAITER"
        ));
        return ResponseEntity.ok(Map.of("status", "accepted", "callId", callId));
    }

    @PostMapping("/waiter/calls/{callId}/resolve")
    public ResponseEntity<Map<String, Object>> resolveWaiterCall(@PathVariable String callId) {
        enqueueDomainEvent("CALL", callId, "CALL_RESOLVED", Map.of(
                "callId", callId,
                "source", "EDGE_WAITER"
        ));
        return ResponseEntity.ok(Map.of("status", "accepted", "callId", callId));
    }

    @PostMapping("/waiter/orders/{orderId}/deliver")
    public ResponseEntity<Map<String, Object>> deliverWaiterOrder(@PathVariable String orderId) {
        enqueueDomainEvent("ORDER", orderId, "ORDER_DELIVERED", Map.of(
                "orderId", orderId,
                "source", "EDGE_WAITER"
        ));
        return ResponseEntity.ok(Map.of("status", "accepted", "orderId", orderId));
    }

    private void enqueueDomainEvent(String aggregateType, String aggregateId, String eventType, Map<String, Object> payload) {
        try {
            outboxService.enqueueEvent(aggregateType, aggregateId, eventType, objectMapper.writeValueAsString(payload));
        } catch (JsonProcessingException ex) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "failed_to_queue_event");
        }
    }

    private String safe(String value) {
        return value == null ? "" : value;
    }

    public record CreateOrderRequest(
            @NotBlank String tableId,
            String note
    ) {}

    public record KitchenStatusUpdateRequest(
            @NotBlank String orderId,
            @NotBlank String status
    ) {}

    public record MarkPaidRequest(
            @NotBlank String paymentId,
            @NotBlank String method
    ) {}
}
