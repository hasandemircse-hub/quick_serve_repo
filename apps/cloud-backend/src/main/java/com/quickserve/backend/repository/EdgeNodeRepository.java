package com.quickserve.backend.repository;

import com.quickserve.backend.entity.EdgeNode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface EdgeNodeRepository extends JpaRepository<EdgeNode, Long> {
    List<EdgeNode> findByRestaurantIdOrderByCreatedAtDesc(Long restaurantId);

    List<EdgeNode> findByRestaurantIdAndIsActiveTrueOrderByCreatedAtDesc(Long restaurantId);

    Optional<EdgeNode> findFirstByRestaurant_IdAndNodeName(Long restaurantId, String nodeName);
}
