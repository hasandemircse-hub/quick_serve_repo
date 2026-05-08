package com.quickserve.backend.repository;

import com.quickserve.backend.entity.EdgeNode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EdgeNodeRepository extends JpaRepository<EdgeNode, Long> {
    List<EdgeNode> findByRestaurantIdOrderByCreatedAtDesc(Long restaurantId);

    List<EdgeNode> findByRestaurantIdAndIsActiveTrueOrderByCreatedAtDesc(Long restaurantId);
}
