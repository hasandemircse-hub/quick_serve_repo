package com.quickserve.backend.repository;

import com.quickserve.backend.entity.EdgeEnrollmentToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface EdgeEnrollmentTokenRepository extends JpaRepository<EdgeEnrollmentToken, Long> {
    Optional<EdgeEnrollmentToken> findByToken(String token);

    List<EdgeEnrollmentToken> findByRestaurantIdOrderByCreatedAtDesc(Long restaurantId);

    Optional<EdgeEnrollmentToken> findByIdAndRestaurantId(Long id, Long restaurantId);

    List<EdgeEnrollmentToken> findByExpiresAtBefore(LocalDateTime now);

    void deleteByExpiresAtBefore(LocalDateTime now);
}
