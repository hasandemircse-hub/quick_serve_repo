package com.quickserve.backend.repository;

import com.quickserve.backend.entity.MenuItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface MenuItemRepository extends JpaRepository<MenuItem, Long> {

    // Aktif ve menüde kaldırılmamış ürünler (müşteri görünümü)
    @Query("SELECT m FROM MenuItem m WHERE m.restaurant.id = :restaurantId " +
           "AND m.isActive = true AND m.isRemoved = false ORDER BY m.category.displayOrder, m.displayOrder")
    List<MenuItem> findVisibleByRestaurantId(@Param("restaurantId") Long restaurantId);

    List<MenuItem> findByRestaurantIdOrderByCategoryDisplayOrderAscDisplayOrderAsc(Long restaurantId);

    List<MenuItem> findByCategoryIdAndIsActiveTrueAndIsRemovedFalseOrderByDisplayOrder(Long categoryId);

    List<MenuItem> findByRestaurantIdAndIsCampaignTrue(Long restaurantId);

    boolean existsByCategoryId(Long categoryId);

    @Query("SELECT m FROM MenuItem m WHERE m.restaurant.id = :restaurantId " +
           "AND (LOWER(m.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(m.nameEn) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<MenuItem> searchByKeyword(@Param("restaurantId") Long restaurantId, @Param("keyword") String keyword);

    @Modifying
    @Query(value = "DELETE FROM menu_item_note_options WHERE menu_item_id IN " +
                   "(SELECT id FROM menu_items WHERE restaurant_id = :restaurantId)", nativeQuery = true)
    void deleteNoteOptionsByRestaurantId(@Param("restaurantId") Long restaurantId);

    @Modifying
    @Query("DELETE FROM MenuItem mi WHERE mi.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
