package com.quickserve.backend.repository;

import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.enums.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface RestaurantRepository extends JpaRepository<Restaurant, Long> {

    Optional<Restaurant> findByNameIgnoreCase(String name);

    List<Restaurant> findAllByOrderByIsActiveDescCreatedAtDesc();

    List<Restaurant> findByIsActiveTrue();

    List<Restaurant> findBySubscriptionStatus(SubscriptionStatus status);

    @Query("SELECT r FROM Restaurant r WHERE r.subscriptionStatus = 'ACTIVE' " +
           "AND r.subscriptionExpiresAt < :now")
    List<Restaurant> findExpiredActiveSubscriptions(@Param("now") LocalDateTime now);

    @Query("SELECT r FROM Restaurant r WHERE r.subscriptionStatus = 'DEMO' " +
           "AND r.demoExpiresAt < :now")
    List<Restaurant> findExpiredDemoRestaurants(@Param("now") LocalDateTime now);
}
