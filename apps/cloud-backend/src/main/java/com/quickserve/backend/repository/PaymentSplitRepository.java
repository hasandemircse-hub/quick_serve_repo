package com.quickserve.backend.repository;

import com.quickserve.backend.entity.PaymentSplit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface PaymentSplitRepository extends JpaRepository<PaymentSplit, Long> {

    List<PaymentSplit> findByTableSessionId(Long sessionId);

    List<PaymentSplit> findByTableSessionIdAndIsPaidFalse(Long sessionId);

    @Modifying
    @Query("DELETE FROM PaymentSplit ps WHERE ps.tableSession.table.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
