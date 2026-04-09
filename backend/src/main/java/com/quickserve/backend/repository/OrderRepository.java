package com.quickserve.backend.repository;

import com.quickserve.backend.model.Order;
import com.quickserve.backend.model.OrderStatus;
import com.quickserve.backend.model.RestaurantTable;
import com.quickserve.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    List<Order> findByTable(RestaurantTable table);
    List<Order> findByStatus(OrderStatus status);
    List<Order> findByWaiter(User waiter);
    List<Order> findByCustomer(User customer);
    Optional<Order> findByTableAndStatus(RestaurantTable table, OrderStatus status);
}
