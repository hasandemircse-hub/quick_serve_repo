package com.quickserve.backend.repository;

import com.quickserve.backend.entity.Order;
import com.quickserve.backend.enums.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface OrderRepository extends JpaRepository<Order, Long> {

    List<Order> findByTableSessionIdOrderByCreatedAtDesc(Long sessionId);

    List<Order> findByTableSessionIdAndStatusNot(Long sessionId, OrderStatus status);

    List<Order> findByRestaurantIdAndStatusOrderByCreatedAt(Long restaurantId, OrderStatus status);

    List<Order> findByRestaurantIdAndStatusIn(Long restaurantId, List<OrderStatus> statuses);

    // Mutfak ekranı: PENDING + PREPARING siparişler
    @Query("SELECT o FROM Order o WHERE o.restaurant.id = :restaurantId " +
           "AND o.status IN ('PENDING', 'PREPARING') ORDER BY o.createdAt ASC")
    List<Order> findKitchenOrders(@Param("restaurantId") Long restaurantId);

    @Query("SELECT o FROM Order o WHERE o.restaurant.id = :restaurantId " +
           "AND o.createdAt BETWEEN :from AND :to ORDER BY o.createdAt DESC")
    List<Order> findByRestaurantAndDateRange(@Param("restaurantId") Long restaurantId,
                                             @Param("from") LocalDateTime from,
                                             @Param("to") LocalDateTime to);

    long countByRestaurantIdAndStatus(Long restaurantId, OrderStatus status);

    @Modifying
    @Query("DELETE FROM Order o WHERE o.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
