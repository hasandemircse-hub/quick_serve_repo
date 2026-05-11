package com.quickserve.backend.repository;

import com.quickserve.backend.entity.EdgeSyncReceivedEvent;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface EdgeSyncReceivedEventRepository extends JpaRepository<EdgeSyncReceivedEvent, Long> {

    boolean existsByEventId(String eventId);

    @Query("""
            SELECT MAX(e.eventTimestampUtc) FROM EdgeSyncReceivedEvent e
            WHERE e.restaurantId = :restaurantId
              AND e.aggregateType = :aggregateType
              AND e.aggregateId = :aggregateId
              AND e.applied = true
            """)
    Optional<Instant> findMaxAppliedEventTimestamp(
            @Param("restaurantId") Long restaurantId,
            @Param("aggregateType") String aggregateType,
            @Param("aggregateId") String aggregateId
    );

    List<EdgeSyncReceivedEvent> findByRestaurantIdAndAppliedIsTrueAndIdGreaterThanOrderByIdAsc(
            Long restaurantId,
            Long afterId,
            Pageable pageable
    );
}
