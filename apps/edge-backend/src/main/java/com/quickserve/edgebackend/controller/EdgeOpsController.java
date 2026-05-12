package com.quickserve.edgebackend.controller;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.quickserve.edgebackend.edge.EdgeSyncPayloadFields;
import com.quickserve.edgebackend.service.EdgeOpsLocalCacheService;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping
public class EdgeOpsController {

    private final EdgeSyncOutboxService outboxService;
    private final EdgeOpsLocalCacheService edgeOpsLocalCacheService;
    private final ObjectMapper objectMapper;

    public EdgeOpsController(
            EdgeSyncOutboxService outboxService,
            EdgeOpsLocalCacheService edgeOpsLocalCacheService,
            ObjectMapper objectMapper
    ) {
        this.outboxService = outboxService;
        this.edgeOpsLocalCacheService = edgeOpsLocalCacheService;
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
        Map<String, Object> payload = basePayload("ORDER", orderId);
        payload.put("orderId", orderId);
        payload.put("tableId", request.tableId());
        payload.put("note", safe(request.note()));
        payload.put("source", "EDGE_WAITER");
        enqueueWriteThrough("ORDER_CREATED", payload);
        return ResponseEntity.ok(Map.of("status", "accepted", "orderId", orderId));
    }

    @PostMapping("/kitchen/orders/status")
    public ResponseEntity<Map<String, Object>> updateKitchenOrderStatus(@Valid @RequestBody KitchenStatusUpdateRequest request) {
        return kitchenStatusChange(request.orderId(), request.status());
    }

    /** Cloud {@code KitchenController} ile aynı yollar — Flutter mutfak ekranı bunları kullanır. */
    @PostMapping("/kitchen/orders/{orderId}/start")
    public ResponseEntity<Map<String, Object>> kitchenStartPreparing(@PathVariable String orderId) {
        return kitchenStatusChange(orderId, "PREPARING");
    }

    @PostMapping("/kitchen/orders/{orderId}/ready")
    public ResponseEntity<Map<String, Object>> kitchenMarkReady(@PathVariable String orderId) {
        return kitchenStatusChange(orderId, "READY");
    }

    private ResponseEntity<Map<String, Object>> kitchenStatusChange(String orderId, String status) {
        Map<String, Object> payload = basePayload("ORDER", orderId);
        payload.put("orderId", orderId);
        payload.put("status", status);
        payload.put("source", "EDGE_KITCHEN");
        enqueueWriteThrough("ORDER_STATUS_UPDATED", payload);
        return ResponseEntity.ok(Map.of("status", "accepted", "orderId", orderId));
    }

    @PostMapping("/admin/payments/mark-paid")
    public ResponseEntity<Map<String, Object>> markPaymentPaid(@Valid @RequestBody MarkPaidRequest request) {
        Map<String, Object> payload = basePayload("PAYMENT", request.paymentId());
        payload.put("paymentId", request.paymentId());
        payload.put("method", request.method());
        payload.put("source", "EDGE_ADMIN");
        enqueueWriteThrough("PAYMENT_MARKED_PAID", payload);
        return ResponseEntity.ok(Map.of("status", "accepted", "paymentId", request.paymentId()));
    }

    @PostMapping("/waiter/calls/{callId}/assign")
    public ResponseEntity<Map<String, Object>> assignWaiterCall(
            @PathVariable String callId,
            @RequestBody(required = false) AssignCallRequest body,
            @RequestParam(name = "waiterId", required = false) String waiterIdParam
    ) {
        String waiterId = body != null ? body.waiterId() : waiterIdParam;
        if (waiterId == null || waiterId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "waiterId_required");
        }
        Map<String, Object> payload = basePayload("CALL", callId);
        payload.put("callId", callId);
        payload.put("waiterId", waiterId);
        payload.put("source", "EDGE_WAITER");
        enqueueWriteThrough("CALL_ASSIGNED", payload);
        return ResponseEntity.ok(Map.of("status", "accepted", "callId", callId));
    }

    @PostMapping("/waiter/calls/{callId}/resolve")
    public ResponseEntity<Map<String, Object>> resolveWaiterCall(@PathVariable String callId) {
        Map<String, Object> payload = basePayload("CALL", callId);
        payload.put("callId", callId);
        payload.put("source", "EDGE_WAITER");
        enqueueWriteThrough("CALL_RESOLVED", payload);
        return ResponseEntity.ok(Map.of("status", "accepted", "callId", callId));
    }

    @PostMapping("/waiter/orders/{orderId}/deliver")
    public ResponseEntity<Map<String, Object>> deliverWaiterOrder(@PathVariable String orderId) {
        Map<String, Object> payload = basePayload("ORDER", orderId);
        payload.put("orderId", orderId);
        payload.put("source", "EDGE_WAITER");
        enqueueWriteThrough("ORDER_DELIVERED", payload);
        return ResponseEntity.ok(Map.of("status", "accepted", "orderId", orderId));
    }

    private Map<String, Object> basePayload(String aggregateType, String aggregateId) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put(EdgeSyncPayloadFields.EVENT_TIMESTAMP_UTC, Instant.now().toString());
        m.put(EdgeSyncPayloadFields.SOURCE_SYSTEM, "EDGE");
        m.put(EdgeSyncPayloadFields.AGGREGATE_TYPE, aggregateType);
        m.put(EdgeSyncPayloadFields.AGGREGATE_ID, aggregateId);
        return m;
    }

    private void enqueueWriteThrough(String eventType, Map<String, Object> payload) {
        try {
            String aggregateType = String.valueOf(payload.get(EdgeSyncPayloadFields.AGGREGATE_TYPE));
            String aggregateId = String.valueOf(payload.get(EdgeSyncPayloadFields.AGGREGATE_ID));
            String json = objectMapper.writeValueAsString(payload);
            String eventId = UUID.randomUUID().toString();
            edgeOpsLocalCacheService.applyLocalWrite(eventType, json, eventId);
            outboxService.enqueueEventWithId(eventId, aggregateType, aggregateId, eventType, json);
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

    public record AssignCallRequest(
            @NotBlank String waiterId
    ) {}
}
