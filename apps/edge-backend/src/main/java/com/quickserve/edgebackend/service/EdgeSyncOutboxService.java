package com.quickserve.edgebackend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class EdgeSyncOutboxService {

    private final JdbcTemplate jdbcTemplate;

    public EdgeSyncOutboxService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * @return outbox satır id (cloud idempotency anahtarı)
     */
    public String enqueueEvent(String aggregateType, String aggregateId, String eventType, String payloadJson) {
        String id = UUID.randomUUID().toString();
        enqueueEventWithId(id, aggregateType, aggregateId, eventType, payloadJson);
        return id;
    }

    public void enqueueEventWithId(String id, String aggregateType, String aggregateId, String eventType, String payloadJson) {
        jdbcTemplate.update("""
                        INSERT INTO edge_sync_outbox (
                            id, aggregate_type, aggregate_id, event_type, payload_json, status, retry_count, next_attempt_at, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, 'PENDING', 0, NULL, datetime('now'), datetime('now'))
                        """,
                id, aggregateType, aggregateId, eventType, payloadJson);
    }

    public List<OutboxEvent> pollPendingEvents(int batchSize) {
        return jdbcTemplate.query("""
                        SELECT id, event_type, payload_json, retry_count
                        FROM edge_sync_outbox
                        WHERE status IN ('PENDING', 'RETRY')
                          AND (next_attempt_at IS NULL OR next_attempt_at <= datetime('now'))
                        ORDER BY created_at
                        LIMIT ?
                        """,
                (rs, rowNum) -> new OutboxEvent(
                        rs.getString("id"),
                        rs.getString("event_type"),
                        rs.getString("payload_json"),
                        rs.getInt("retry_count")
                ),
                batchSize);
    }

    public void markSent(String eventId) {
        jdbcTemplate.update("""
                        UPDATE edge_sync_outbox
                        SET status='SENT', updated_at=datetime('now')
                        WHERE id=?
                        """,
                eventId);
    }

    public void markRetry(String eventId, int retryCount, int backoffSeconds, String reason) {
        jdbcTemplate.update("""
                        UPDATE edge_sync_outbox
                        SET status='RETRY',
                            retry_count=?,
                            last_error=?,
                            next_attempt_at=datetime('now', printf('+%d seconds', ?)),
                            updated_at=datetime('now')
                        WHERE id=?
                        """,
                retryCount, reason, backoffSeconds, eventId);
    }

    public void markDead(String eventId, int retryCount, String reason) {
        jdbcTemplate.update("""
                        UPDATE edge_sync_outbox
                        SET status='DEAD',
                            retry_count=?,
                            last_error=?,
                            updated_at=datetime('now')
                        WHERE id=?
                        """,
                retryCount, reason, eventId);
    }

    public SyncQueueStats getQueueStats() {
        Map<String, Object> stats = jdbcTemplate.queryForMap("""
                SELECT
                  SUM(CASE WHEN status='PENDING' THEN 1 ELSE 0 END) AS pending_count,
                  SUM(CASE WHEN status='RETRY' THEN 1 ELSE 0 END) AS retry_count,
                  SUM(CASE WHEN status='DEAD' THEN 1 ELSE 0 END) AS dead_count,
                  MIN(CASE WHEN status IN ('PENDING','RETRY') THEN created_at ELSE NULL END) AS oldest_waiting_created_at
                FROM edge_sync_outbox
                """);

        long pendingCount = toLong(stats.get("pending_count"));
        long retryCount = toLong(stats.get("retry_count"));
        long deadCount = toLong(stats.get("dead_count"));
        Long oldestWaitingAgeSeconds = jdbcTemplate.queryForObject("""
                SELECT
                  CAST((strftime('%s','now') - strftime('%s', MIN(created_at))) AS INTEGER)
                FROM edge_sync_outbox
                WHERE status IN ('PENDING','RETRY')
                """, Long.class);

        return new SyncQueueStats(
                pendingCount,
                retryCount,
                deadCount,
                oldestWaitingAgeSeconds
        );
    }

    public int purgeSentOlderThanDays(int days) {
        return jdbcTemplate.update("""
                        DELETE FROM edge_sync_outbox
                        WHERE status='SENT'
                          AND updated_at <= datetime('now', printf('-%d days', ?))
                        """,
                days);
    }

    public int purgeDeadOlderThanDays(int days) {
        return jdbcTemplate.update("""
                        DELETE FROM edge_sync_outbox
                        WHERE status='DEAD'
                          AND updated_at <= datetime('now', printf('-%d days', ?))
                        """,
                days);
    }

    private long toLong(Object value) {
        if (value == null) return 0L;
        if (value instanceof Number number) return number.longValue();
        return Long.parseLong(value.toString());
    }

    public record OutboxEvent(String id, String eventType, String payloadJson, int retryCount) {}

    public record SyncQueueStats(
            long pendingCount,
            long retryCount,
            long deadCount,
            Long oldestWaitingAgeSeconds
    ) {}
}
