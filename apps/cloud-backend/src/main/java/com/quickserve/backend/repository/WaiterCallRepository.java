package com.quickserve.backend.repository;

import com.quickserve.backend.entity.WaiterCall;
import com.quickserve.backend.enums.WaiterCallStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface WaiterCallRepository extends JpaRepository<WaiterCall, Long> {

    List<WaiterCall> findByRestaurantIdAndStatusOrderByCalledAtAsc(Long restaurantId, WaiterCallStatus status);

    List<WaiterCall> findByRestaurantIdAndStatusIn(Long restaurantId, List<WaiterCallStatus> statuses);

    List<WaiterCall> findByAssignedToIdAndStatusNot(Long userId, WaiterCallStatus status);

    long countByRestaurantIdAndStatus(Long restaurantId, WaiterCallStatus status);

    // Garson çağırma performansı: garsonun üzerine aldığı çağrılar
    long countByAssignedToId(Long waiterId);

    @Modifying
    @Query("DELETE FROM WaiterCall wc WHERE wc.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
