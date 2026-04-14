package com.quickserve.backend.repository;

import com.quickserve.backend.entity.RestaurantTable;
import com.quickserve.backend.enums.TableStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface RestaurantTableRepository extends JpaRepository<RestaurantTable, Long> {

    List<RestaurantTable> findByRestaurantIdOrderByTableNumber(Long restaurantId);

    List<RestaurantTable> findByRestaurantIdAndStatus(Long restaurantId, TableStatus status);

    Optional<RestaurantTable> findByQrToken(String qrToken);

    Optional<RestaurantTable> findByRestaurantIdAndTableNumber(Long restaurantId, String tableNumber);

    boolean existsByRestaurantIdAndTableNumber(Long restaurantId, String tableNumber);

    long countByRestaurantIdAndStatus(Long restaurantId, TableStatus status);

    @Modifying
    @Query("DELETE FROM RestaurantTable rt WHERE rt.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
