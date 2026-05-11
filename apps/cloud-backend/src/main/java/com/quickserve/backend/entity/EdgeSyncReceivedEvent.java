package com.quickserve.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

/**
 * Edge'den gelen senkron olayları: idempotency (eventId), LWW (eventTimestampUtc) ve cursor (id) için kayıt.
 */
@Entity
@Table(name = "edge_sync_received_events", indexes = {
        @Index(name = "idx_edge_sync_recv_restaurant_id", columnList = "restaurant_id"),
        @Index(name = "idx_edge_sync_recv_restaurant_applied_id", columnList = "restaurant_id, applied, id")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EdgeSyncReceivedEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "event_id", nullable = false, unique = true, length = 64)
    private String eventId;

    @Column(name = "restaurant_id", nullable = false)
    private Long restaurantId;

    @Column(name = "aggregate_type", nullable = false, length = 32)
    private String aggregateType;

    @Column(name = "aggregate_id", nullable = false, length = 128)
    private String aggregateId;

    @Column(name = "event_type", nullable = false, length = 64)
    private String eventType;

    @Column(name = "event_timestamp_utc", nullable = false)
    private Instant eventTimestampUtc;

    @Column(name = "applied", nullable = false)
    @Builder.Default
    private boolean applied = false;

    /** Örn: OLDER_THAN_APPLIED, UNSUPPORTED_EVENT */
    @Column(name = "discarded_reason", length = 64)
    private String discardedReason;

    @Column(name = "payload_json", columnDefinition = "TEXT")
    private String payloadJson;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
