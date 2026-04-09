package com.quickserve.backend.service;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.quickserve.backend.model.Order;
import com.quickserve.backend.model.OrderStatus;
import com.quickserve.backend.model.RestaurantTable;
import com.quickserve.backend.model.User;
import com.quickserve.backend.repository.OrderRepository;

@Service
public class OrderService {
    @Autowired
    private OrderRepository orderRepository;

    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }

    public Optional<Order> getOrderById(Long id) {
        return orderRepository.findById(id);
    }

    public Order createOrder(Order order) {
        return orderRepository.save(order);
    }

    public Order updateOrder(Long id, Order orderDetails) {
        return orderRepository.findById(id).map(order -> {
            order.setStatus(orderDetails.getStatus());
            order.setWaiter(orderDetails.getWaiter());
            order.setNotes(orderDetails.getNotes());
            order.setTotalAmount(orderDetails.getTotalAmount());
            return orderRepository.save(order);
        }).orElseThrow(() -> new RuntimeException("Sipariş bulunamadı"));
    }

    public void deleteOrder(Long id) {
        orderRepository.deleteById(id);
    }

    public List<Order> getOrdersByTable(RestaurantTable table) {
        return orderRepository.findByTable(table);
    }

    public List<Order> getOrdersByStatus(OrderStatus status) {
        return orderRepository.findByStatus(status);
    }

    public List<Order> getOrdersByWaiter(User waiter) {
        return orderRepository.findByWaiter(waiter);
    }

    public List<Order> getPendingOrders() {
        return orderRepository.findByStatus(OrderStatus.PENDING);
    }

    public List<Order> getPreparingOrders() {
        return orderRepository.findByStatus(OrderStatus.PREPARING);
    }

    public List<Order> getReadyOrders() {
        return orderRepository.findByStatus(OrderStatus.READY);
    }

    public void updateOrderStatus(Long orderId, OrderStatus status) {
        orderRepository.findById(orderId).ifPresent(order -> {
            order.setStatus(status);
            orderRepository.save(order);
        });
    }

    public Optional<Order> getActiveOrderOnTable(RestaurantTable table) {
        return orderRepository.findByTableAndStatus(table, OrderStatus.PENDING);
    }
}
