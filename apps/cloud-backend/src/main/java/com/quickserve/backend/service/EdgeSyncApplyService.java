package com.quickserve.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.quickserve.backend.edge.EdgeSyncEventFields;
import com.quickserve.backend.entity.EdgeSyncReceivedEvent;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.enums.PaymentMethod;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.repository.EdgeSyncReceivedEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Edge → Cloud domain olaylarını idempotent + LWW ile uygular.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EdgeSyncApplyService {

    private final EdgeSyncReceivedEventRepository receivedEventRepository;
    private final OrderService orderService;
    private final WaiterCallService waiterCallService;
    private final PaymentService paymentService;
    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    @Transactional
    public void apply(String eventId, String eventType, String payloadJson, Long restaurantId) {
        if (receivedEventRepository.existsByEventId(eventId)) {
            log.debug("Edge sync duplicate eventId={}, skip", eventId);
            return;
        }

        JsonNode root = parsePayload(payloadJson);
        String aggregateType = text(root, EdgeSyncEventFields.AGGREGATE_TYPE);
        String aggregateId = text(root, EdgeSyncEventFields.AGGREGATE_ID);
        if (aggregateType == null || aggregateType.isBlank()) {
            aggregateType = inferAggregateType(eventType);
        }
        if (aggregateId == null || aggregateId.isBlank()) {
            aggregateId = inferAggregateId(root);
        }

        Instant eventTs = parseInstant(root.get(EdgeSyncEventFields.EVENT_TIMESTAMP_UTC))
                .orElse(Instant.now());

        Optional<Instant> maxApplied = receivedEventRepository.findMaxAppliedEventTimestamp(
                restaurantId, aggregateType, aggregateId);
        if (maxApplied.isPresent() && eventTs.isBefore(maxApplied.get())) {
            saveRecord(eventId, restaurantId, aggregateType, aggregateId, eventType, eventTs, false,
                    "OLDER_THAN_APPLIED", payloadJson);
            log.info("Edge sync discarded older event eventId={} agg={}:{}", eventId, aggregateType, aggregateId);
            publishEdgeOps(restaurantId, eventType, aggregateType, aggregateId, false, "OLDER_THAN_APPLIED");
            return;
        }

        if ("ORDER_CREATED".equals(eventType)) {
            saveRecord(eventId, restaurantId, aggregateType, aggregateId, eventType, eventTs, false,
                    "UNSUPPORTED_EVENT", payloadJson);
            publishEdgeOps(restaurantId, eventType, aggregateType, aggregateId, false, "UNSUPPORTED_EVENT");
            return;
        }

        try {
            applyDomain(restaurantId, eventType, root);
            saveRecord(eventId, restaurantId, aggregateType, aggregateId, eventType, eventTs, true, null, payloadJson);
            publishEdgeOps(restaurantId, eventType, aggregateType, aggregateId, true, null);
        } catch (BusinessException | IllegalArgumentException ex) {
            log.warn("Edge sync domain apply failed eventId={} type={}: {}", eventId, eventType, ex.getMessage());
            throw ex;
        }
    }

    private void applyDomain(Long restaurantId, String eventType, JsonNode root) {
        switch (eventType) {
            case "ORDER_STATUS_UPDATED" -> {
                long orderId = requireLong(root, "orderId");
                assertOrderRestaurant(restaurantId, orderId);
                OrderStatus st = OrderStatus.valueOf(requireText(root, "status"));
                orderService.updateStatus(orderId, st);
            }
            case "ORDER_DELIVERED" -> {
                long orderId = requireLong(root, "orderId");
                assertOrderRestaurant(restaurantId, orderId);
                orderService.updateStatus(orderId, OrderStatus.DELIVERED);
            }
            case "CALL_ASSIGNED" -> {
                long callId = requireLong(root, "callId");
                long waiterId = requireLong(root, "waiterId");
                var call = waiterCallService.findById(callId);
                if (!call.getRestaurant().getId().equals(restaurantId)) {
                    throw new BusinessException("Çağrı restorana ait değil");
                }
                waiterCallService.assignCall(callId, waiterId);
            }
            case "CALL_RESOLVED" -> {
                long callId = requireLong(root, "callId");
                var call = waiterCallService.findById(callId);
                if (!call.getRestaurant().getId().equals(restaurantId)) {
                    throw new BusinessException("Çağrı restorana ait değil");
                }
                waiterCallService.resolveCall(callId);
            }
            case "PAYMENT_MARKED_PAID" -> {
                long paymentId = requireLong(root, "paymentId");
                PaymentMethod method = PaymentMethod.valueOf(requireText(root, "method"));
                paymentService.markPaymentCompletedFromEdgeBridge(restaurantId, paymentId, method);
            }
            default -> throw new BusinessException("Bilinmeyen edge eventType: " + eventType);
        }
    }

    private void assertOrderRestaurant(Long restaurantId, long orderId) {
        var order = orderService.findById(orderId);
        if (!order.getRestaurant().getId().equals(restaurantId)) {
            throw new BusinessException("Sipariş restorana ait değil");
        }
    }

    private void publishEdgeOps(
            Long restaurantId,
            String eventType,
            String aggregateType,
            String aggregateId,
            boolean applied,
            String reason
    ) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("eventType", eventType);
        payload.put("aggregateType", aggregateType);
        payload.put("aggregateId", aggregateId);
        payload.put("applied", applied);
        payload.put("discardedReason", reason);
        payload.put("occurredAt", Instant.now().toString());
        notificationService.publishToRestaurant(restaurantId, "edge_ops", payload);
    }

    private void saveRecord(
            String eventId,
            Long restaurantId,
            String aggregateType,
            String aggregateId,
            String eventType,
            Instant eventTs,
            boolean applied,
            String discardedReason,
            String payloadJson
    ) {
        receivedEventRepository.save(EdgeSyncReceivedEvent.builder()
                .eventId(eventId)
                .restaurantId(restaurantId)
                .aggregateType(aggregateType)
                .aggregateId(aggregateId)
                .eventType(eventType)
                .eventTimestampUtc(eventTs)
                .applied(applied)
                .discardedReason(discardedReason)
                .payloadJson(truncate(payloadJson, 8000))
                .build());
    }

    private JsonNode parsePayload(String payloadJson) {
        if (payloadJson == null || payloadJson.isBlank()) {
            return objectMapper.createObjectNode();
        }
        try {
            return objectMapper.readTree(payloadJson);
        } catch (Exception e) {
            throw new BusinessException("payload_json geçersiz JSON");
        }
    }

    private static String text(JsonNode root, String field) {
        if (root == null || !root.has(field) || root.get(field).isNull()) {
            return null;
        }
        return root.get(field).asText(null);
    }

    private static String requireText(JsonNode root, String field) {
        String v = text(root, field);
        if (v == null || v.isBlank()) {
            throw new BusinessException("Eksik alan: " + field);
        }
        return v;
    }

    private static long requireLong(JsonNode root, String field) {
        String v = requireText(root, field);
        try {
            return Long.parseLong(v.trim());
        } catch (NumberFormatException e) {
            throw new BusinessException("Geçersiz sayı alanı: " + field);
        }
    }

    private static Optional<Instant> parseInstant(JsonNode n) {
        if (n == null || n.isNull() || !n.isTextual()) {
            return Optional.empty();
        }
        try {
            return Optional.of(Instant.parse(n.asText()));
        } catch (DateTimeParseException e) {
            return Optional.empty();
        }
    }

    private static String inferAggregateType(String eventType) {
        if (eventType == null) {
            return "UNKNOWN";
        }
        if (eventType.contains("ORDER")) {
            return "ORDER";
        }
        if (eventType.contains("CALL")) {
            return "CALL";
        }
        if (eventType.contains("PAYMENT")) {
            return "PAYMENT";
        }
        return "UNKNOWN";
    }

    private static String inferAggregateId(JsonNode root) {
        if (root.hasNonNull("orderId")) {
            return root.get("orderId").asText();
        }
        if (root.hasNonNull("callId")) {
            return root.get("callId").asText();
        }
        if (root.hasNonNull("paymentId")) {
            return root.get("paymentId").asText();
        }
        return "unknown";
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return null;
        }
        return s.length() <= max ? s : s.substring(0, max);
    }
}
