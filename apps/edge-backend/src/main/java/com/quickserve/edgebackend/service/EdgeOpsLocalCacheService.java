package com.quickserve.edgebackend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.quickserve.edgebackend.edge.EdgeSyncPayloadFields;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.Optional;

/**
 * Edge SQLite üzerinde operasyonel state (LWW) + ops changes cursor.
 */
@Service
public class EdgeOpsLocalCacheService {

    private static final String META_OPS_CURSOR = "ops_changes_cursor";

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public EdgeOpsLocalCacheService(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    public long getOpsChangesCursor() {
        try {
            String v = jdbcTemplate.queryForObject(
                    "SELECT v FROM edge_ops_meta WHERE k = ?",
                    String.class,
                    META_OPS_CURSOR
            );
            if (v == null || v.isBlank()) {
                return 0L;
            }
            return Long.parseLong(v.trim());
        } catch (EmptyResultDataAccessException e) {
            return 0L;
        } catch (NumberFormatException e) {
            return 0L;
        }
    }

    public void setOpsChangesCursor(long id) {
        jdbcTemplate.update("""
                        INSERT INTO edge_ops_meta (k, v, updated_at) VALUES (?, ?, datetime('now'))
                        ON CONFLICT(k) DO UPDATE SET v = excluded.v, updated_at = datetime('now')
                        """,
                META_OPS_CURSOR, String.valueOf(id));
    }

    /**
     * Yerel yazma (write-through): her zaman uygulanır (UI anında).
     */
    public void applyLocalWrite(String eventType, String payloadJson, String eventId) {
        applyInternal(eventType, payloadJson, eventId, true);
    }

    /**
     * Cloud'dan çekilen uygulanmış olaylar: payload'daki zamana göre LWW.
     */
    public void applyCloudReplay(String eventType, String payloadJson, String eventId) {
        applyInternal(eventType, payloadJson, eventId, false);
    }

    private void applyInternal(String eventType, String payloadJson, String eventId, boolean forceLocal) {
        JsonNode root = readTree(payloadJson);
        Instant ts = parseInstant(root.path(EdgeSyncPayloadFields.EVENT_TIMESTAMP_UTC)).orElse(Instant.now());
        switch (eventType) {
            case "ORDER_STATUS_UPDATED" -> {
                String orderId = text(root, "orderId");
                String status = text(root, "status");
                if (orderId != null && status != null) {
                    upsertOrder(orderId, status, ts, eventId, payloadJson, forceLocal);
                }
            }
            case "ORDER_DELIVERED" -> {
                String orderId = text(root, "orderId");
                if (orderId != null) {
                    upsertOrder(orderId, "DELIVERED", ts, eventId, payloadJson, forceLocal);
                }
            }
            case "CALL_ASSIGNED" -> {
                String callId = text(root, "callId");
                String waiterId = text(root, "waiterId");
                if (callId != null) {
                    // Cloud WaiterCallStatus.IN_PROGRESS ile uyumlu
                    upsertCall(callId, "IN_PROGRESS", waiterId, ts, eventId, payloadJson, forceLocal);
                }
            }
            case "CALL_RESOLVED" -> {
                String callId = text(root, "callId");
                if (callId != null) {
                    upsertCall(callId, "RESOLVED", null, ts, eventId, payloadJson, forceLocal);
                }
            }
            case "PAYMENT_MARKED_PAID" -> {
                String paymentId = text(root, "paymentId");
                String method = text(root, "method");
                if (paymentId != null) {
                    upsertPayment(paymentId, "COMPLETED", method, ts, eventId, payloadJson, forceLocal);
                }
            }
            case "ORDER_CREATED" -> {
                // Snapshot + cloud kaynaklı gerçek sipariş id'leri ile doldurulur; burada no-op.
            }
            default -> {
                // ignore unknown
            }
        }
    }

    public Optional<String> getOrderStatus(String orderId) {
        try {
            String st = jdbcTemplate.queryForObject(
                    "SELECT status FROM edge_ops_order WHERE order_id = ?",
                    String.class,
                    orderId
            );
            return Optional.ofNullable(st);
        } catch (EmptyResultDataAccessException e) {
            return Optional.empty();
        }
    }

    public Optional<String> getCallStatus(String callId) {
        try {
            String st = jdbcTemplate.queryForObject(
                    "SELECT status FROM edge_ops_call WHERE call_id = ?",
                    String.class,
                    callId
            );
            return Optional.ofNullable(st);
        } catch (EmptyResultDataAccessException e) {
            return Optional.empty();
        }
    }

    public Optional<String> getCallWaiterId(String callId) {
        try {
            String w = jdbcTemplate.queryForObject(
                    "SELECT waiter_id FROM edge_ops_call WHERE call_id = ?",
                    String.class,
                    callId
            );
            return Optional.ofNullable(w);
        } catch (EmptyResultDataAccessException e) {
            return Optional.empty();
        }
    }

    private void upsertOrder(
            String orderId,
            String status,
            Instant ts,
            String eventId,
            String payloadJson,
            boolean forceLocal
    ) {
        String tsStr = ts.toString();
        int force = forceLocal ? 1 : 0;
        jdbcTemplate.update("""
                        INSERT INTO edge_ops_order (order_id, status, last_updated_at_utc, last_event_id, payload_json)
                        VALUES (?, ?, ?, ?, ?)
                        ON CONFLICT(order_id) DO UPDATE SET
                          status = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_order.last_updated_at_utc
                            THEN excluded.status ELSE edge_ops_order.status END,
                          last_updated_at_utc = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_order.last_updated_at_utc
                            THEN excluded.last_updated_at_utc ELSE edge_ops_order.last_updated_at_utc END,
                          last_event_id = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_order.last_updated_at_utc
                            THEN excluded.last_event_id ELSE edge_ops_order.last_event_id END,
                          payload_json = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_order.last_updated_at_utc
                            THEN excluded.payload_json ELSE edge_ops_order.payload_json END
                        """,
                orderId, status, tsStr, eventId, truncate(payloadJson, 8000),
                force, force, force, force
        );
    }

    private void upsertCall(
            String callId,
            String status,
            String waiterId,
            Instant ts,
            String eventId,
            String payloadJson,
            boolean forceLocal
    ) {
        String tsStr = ts.toString();
        int force = forceLocal ? 1 : 0;
        jdbcTemplate.update("""
                        INSERT INTO edge_ops_call (call_id, status, waiter_id, last_updated_at_utc, last_event_id, payload_json)
                        VALUES (?, ?, ?, ?, ?, ?)
                        ON CONFLICT(call_id) DO UPDATE SET
                          status = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_call.last_updated_at_utc
                            THEN excluded.status ELSE edge_ops_call.status END,
                          waiter_id = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_call.last_updated_at_utc
                            THEN excluded.waiter_id ELSE edge_ops_call.waiter_id END,
                          last_updated_at_utc = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_call.last_updated_at_utc
                            THEN excluded.last_updated_at_utc ELSE edge_ops_call.last_updated_at_utc END,
                          last_event_id = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_call.last_updated_at_utc
                            THEN excluded.last_event_id ELSE edge_ops_call.last_event_id END,
                          payload_json = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_call.last_updated_at_utc
                            THEN excluded.payload_json ELSE edge_ops_call.payload_json END
                        """,
                callId, status, waiterId, tsStr, eventId, truncate(payloadJson, 8000),
                force, force, force, force, force
        );
    }

    private void upsertPayment(
            String paymentId,
            String status,
            String method,
            Instant ts,
            String eventId,
            String payloadJson,
            boolean forceLocal
    ) {
        String tsStr = ts.toString();
        int force = forceLocal ? 1 : 0;
        jdbcTemplate.update("""
                        INSERT INTO edge_ops_payment (payment_id, status, method, last_updated_at_utc, last_event_id, payload_json)
                        VALUES (?, ?, ?, ?, ?, ?)
                        ON CONFLICT(payment_id) DO UPDATE SET
                          status = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_payment.last_updated_at_utc
                            THEN excluded.status ELSE edge_ops_payment.status END,
                          method = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_payment.last_updated_at_utc
                            THEN excluded.method ELSE edge_ops_payment.method END,
                          last_updated_at_utc = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_payment.last_updated_at_utc
                            THEN excluded.last_updated_at_utc ELSE edge_ops_payment.last_updated_at_utc END,
                          last_event_id = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_payment.last_updated_at_utc
                            THEN excluded.last_event_id ELSE edge_ops_payment.last_event_id END,
                          payload_json = CASE WHEN ? != 0 OR excluded.last_updated_at_utc >= edge_ops_payment.last_updated_at_utc
                            THEN excluded.payload_json ELSE edge_ops_payment.payload_json END
                        """,
                paymentId, status, method, tsStr, eventId, truncate(payloadJson, 8000),
                force, force, force, force, force
        );
    }

    private JsonNode readTree(String json) {
        if (json == null || json.isBlank()) {
            return objectMapper.createObjectNode();
        }
        try {
            return objectMapper.readTree(json);
        } catch (Exception e) {
            return objectMapper.createObjectNode();
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

    private static String text(JsonNode root, String field) {
        if (root == null || !root.has(field) || root.get(field).isNull()) {
            return null;
        }
        return root.get(field).asText(null);
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return null;
        }
        return s.length() <= max ? s : s.substring(0, max);
    }
}
