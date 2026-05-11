package com.quickserve.backend.repository;

import com.quickserve.backend.entity.EdgeEnrollmentToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface EdgeEnrollmentTokenRepository extends JpaRepository<EdgeEnrollmentToken, Long> {
    Optional<EdgeEnrollmentToken> findByToken(String token);

    List<EdgeEnrollmentToken> findByRestaurantIdOrderByCreatedAtDesc(Long restaurantId);

    Optional<EdgeEnrollmentToken> findByIdAndRestaurantId(Long id, Long restaurantId);

    List<EdgeEnrollmentToken> findByExpiresAtBefore(LocalDateTime now);

    void deleteByExpiresAtBefore(LocalDateTime now);

    @Modifying(clearAutomatically = true)
    @Query("DELETE FROM EdgeEnrollmentToken e WHERE e.restaurant.id = :restaurantId AND e.expiresAt < :now")
    int deleteByRestaurantIdAndExpiresAtBefore(
            @Param("restaurantId") Long restaurantId,
            @Param("now") LocalDateTime now);
}
