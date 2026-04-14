package com.quickserve.backend.repository;

import com.quickserve.backend.entity.MenuCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface MenuCategoryRepository extends JpaRepository<MenuCategory, Long> {

    List<MenuCategory> findByRestaurantIdAndIsActiveTrueOrderByDisplayOrder(Long restaurantId);

    List<MenuCategory> findByRestaurantIdOrderByDisplayOrder(Long restaurantId);

    boolean existsByRestaurantIdAndNameIgnoreCase(Long restaurantId, String name);

    @Modifying
    @Query("DELETE FROM MenuCategory mc WHERE mc.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
