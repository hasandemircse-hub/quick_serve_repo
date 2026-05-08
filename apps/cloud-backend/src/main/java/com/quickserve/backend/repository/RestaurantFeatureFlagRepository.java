package com.quickserve.backend.repository;

import com.quickserve.backend.entity.RestaurantFeatureFlag;
import com.quickserve.backend.enums.FeatureCode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface RestaurantFeatureFlagRepository extends JpaRepository<RestaurantFeatureFlag, Long> {
    List<RestaurantFeatureFlag> findByRestaurantIdOrderByFeatureCodeAsc(Long restaurantId);

    Optional<RestaurantFeatureFlag> findByRestaurantIdAndFeatureCode(Long restaurantId, FeatureCode featureCode);
}
