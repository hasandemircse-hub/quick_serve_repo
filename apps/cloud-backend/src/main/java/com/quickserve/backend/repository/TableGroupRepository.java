package com.quickserve.backend.repository;

import com.quickserve.backend.entity.TableGroup;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TableGroupRepository extends JpaRepository<TableGroup, Long> {

    List<TableGroup> findByRestaurantIdOrderByDisplayOrder(Long restaurantId);

    boolean existsByRestaurantIdAndNameIgnoreCase(Long restaurantId, String name);

    @Modifying
    @Query("DELETE FROM TableGroup g WHERE g.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
