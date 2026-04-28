package com.quickserve.backend.repository;

import com.quickserve.backend.entity.TableSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface TableSessionRepository extends JpaRepository<TableSession, Long> {

    Optional<TableSession> findBySessionToken(String sessionToken);

    Optional<TableSession> findByTableIdAndIsActiveTrue(Long tableId);

    List<TableSession> findByTableRestaurantIdAndIsActiveTrue(Long restaurantId);

    @Query("SELECT ts FROM TableSession ts WHERE ts.table.id = :tableId ORDER BY ts.openedAt DESC")
    List<TableSession> findAllByTableIdOrderByOpenedAtDesc(@Param("tableId") Long tableId);

    @Query("SELECT ts.table.restaurant.id FROM TableSession ts WHERE ts.id = :sessionId")
    Optional<Long> findRestaurantIdBySessionId(@Param("sessionId") Long sessionId);

    boolean existsBySessionToken(String sessionToken);

    @Modifying
    @Query("DELETE FROM TableSession ts WHERE ts.table.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
