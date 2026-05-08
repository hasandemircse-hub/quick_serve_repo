package com.quickserve.edgebackend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class EdgeSyncInboxService {

    private final JdbcTemplate jdbcTemplate;

    public EdgeSyncInboxService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean saveIfNew(String sourceEventId, String sourceSystem, String payloadJson) {
        int updated = jdbcTemplate.update("""
                        INSERT INTO edge_sync_inbox (
                            id, source_event_id, source_system, payload_json, processed, status, retry_count, created_at, updated_at
                        )
                        VALUES (lower(hex(randomblob(16))), ?, ?, ?, 0, 'PENDING', 0, datetime('now'), datetime('now'))
                        ON CONFLICT(source_system, source_event_id) DO NOTHING
                        """,
                sourceEventId, sourceSystem, payloadJson);
        return updated > 0;
    }

    public void markProcessed(String sourceEventId, String sourceSystem) {
        jdbcTemplate.update("""
                        UPDATE edge_sync_inbox
                        SET processed=1,
                            status='PROCESSED',
                            processed_at=datetime('now'),
                            updated_at=datetime('now')
                        WHERE source_event_id=? AND source_system=?
                        """,
                sourceEventId, sourceSystem);
    }

    public int getRetryCount(String sourceEventId, String sourceSystem) {
        Integer retryCount = jdbcTemplate.queryForObject("""
                        SELECT retry_count
                        FROM edge_sync_inbox
                        WHERE source_event_id=? AND source_system=?
                        """,
                Integer.class,
                sourceEventId, sourceSystem);
        return retryCount == null ? 0 : retryCount;
    }

    public void markRetry(String sourceEventId, String sourceSystem, int retryCount, int backoffSeconds, String reason) {
        jdbcTemplate.update("""
                        UPDATE edge_sync_inbox
                        SET status='RETRY',
                            retry_count=?,
                            last_error=?,
                            next_attempt_at=datetime('now', printf('+%d seconds', ?)),
                            updated_at=datetime('now')
                        WHERE source_event_id=? AND source_system=?
                        """,
                retryCount, reason, backoffSeconds, sourceEventId, sourceSystem);
    }

    public void markDead(String sourceEventId, String sourceSystem, int retryCount, String reason) {
        jdbcTemplate.update("""
                        UPDATE edge_sync_inbox
                        SET status='DEAD',
                            retry_count=?,
                            last_error=?,
                            updated_at=datetime('now')
                        WHERE source_event_id=? AND source_system=?
                        """,
                retryCount, reason, sourceEventId, sourceSystem);
    }

    public List<InboxEvent> pollRetryableEvents(int batchSize) {
        return jdbcTemplate.query("""
                        SELECT source_event_id, source_system, payload_json, retry_count
                        FROM edge_sync_inbox
                        WHERE status='RETRY'
                          AND next_attempt_at IS NOT NULL
                          AND next_attempt_at <= datetime('now')
                        ORDER BY updated_at
                        LIMIT ?
                        """,
                (rs, rowNum) -> new InboxEvent(
                        rs.getString("source_event_id"),
                        rs.getString("source_system"),
                        rs.getString("payload_json"),
                        rs.getInt("retry_count")
                ),
                batchSize);
    }

    public InboxQueueStats getQueueStats() {
        Map<String, Object> stats = jdbcTemplate.queryForMap("""
                SELECT
                  SUM(CASE WHEN status='RETRY' THEN 1 ELSE 0 END) AS retry_count,
                  SUM(CASE WHEN status='DEAD' THEN 1 ELSE 0 END) AS dead_count
                FROM edge_sync_inbox
                """);
        return new InboxQueueStats(
                toLong(stats.get("retry_count")),
                toLong(stats.get("dead_count"))
        );
    }

    public int purgeProcessedOlderThanDays(int days) {
        return jdbcTemplate.update("""
                        DELETE FROM edge_sync_inbox
                        WHERE status='PROCESSED'
                          AND updated_at <= datetime('now', printf('-%d days', ?))
                        """,
                days);
    }

    public int purgeDeadOlderThanDays(int days) {
        return jdbcTemplate.update("""
                        DELETE FROM edge_sync_inbox
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

    public record InboxEvent(String sourceEventId, String sourceSystem, String payloadJson, int retryCount) {}

    public record InboxQueueStats(long retryCount, long deadCount) {}
}
