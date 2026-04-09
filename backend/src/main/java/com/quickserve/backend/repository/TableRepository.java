package com.quickserve.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.quickserve.backend.model.RestaurantTable;
import com.quickserve.backend.model.TableStatus;

@Repository
public interface TableRepository extends JpaRepository<RestaurantTable, Long> {
    Optional<RestaurantTable> findByTableNumber(Integer tableNumber);
    List<RestaurantTable> findByStatus(TableStatus status);
    Optional<RestaurantTable> findByQrCode(String qrCode);
}
