package com.quickserve.backend.repository;

import com.quickserve.backend.entity.Subscription;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {

    List<Subscription> findByRestaurantIdOrderByDueDateDesc(Long restaurantId);

    Optional<Subscription> findTopByRestaurantIdOrderByDueDateDesc(Long restaurantId);

    // Vadesi geçmiş ve ödenmemiş, bildirim gönderilmemiş abonelikler
    List<Subscription> findByIsPaidFalseAndDueDateBeforeAndOverdueNotifiedFalse(LocalDate date);

    // Tüm ödenmemiş gecikmişler
    List<Subscription> findByIsPaidFalseAndDueDateBefore(LocalDate date);

    @Modifying
    @Query("DELETE FROM Subscription s WHERE s.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
