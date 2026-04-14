package com.quickserve.backend.service;

import com.quickserve.backend.dto.order.*;
import com.quickserve.backend.entity.*;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final TableSessionRepository sessionRepository;
    private final MenuService menuService;
    private final NotificationService notificationService;

    /**
     * Müşteri sipariş verir (oturum token ile doğrulanır).
     */
    @Transactional
    public OrderResponse createOrder(String sessionToken, OrderRequest request) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));

        if (!session.getIsActive()) {
            throw new BusinessException("Bu oturum artık aktif değil");
        }

        Restaurant restaurant = session.getTable().getRestaurant();

        Order order = Order.builder()
                .tableSession(session)
                .restaurant(restaurant)
                .status(OrderStatus.PENDING)
                .items(new ArrayList<>())
                .build();

        BigDecimal total = BigDecimal.ZERO;
        for (OrderItemRequest itemReq : request.getItems()) {
            MenuItem menuItem = menuService.findItemById(itemReq.getMenuItemId());

            if (!menuItem.getIsAvailable() || menuItem.getIsRemoved()) {
                throw new BusinessException("Ürün şu an mevcut değil: " + menuItem.getName());
            }

            BigDecimal unitPrice = menuItem.getEffectivePrice();
            OrderItem orderItem = OrderItem.builder()
                    .order(order)
                    .menuItem(menuItem)
                    .quantity(itemReq.getQuantity())
                    .unitPrice(unitPrice)
                    .note(itemReq.getNote())
                    .selectedNoteOptions(itemReq.getSelectedNoteOptions() != null
                            ? itemReq.getSelectedNoteOptions() : new ArrayList<>())
                    .status(OrderStatus.PENDING)
                    .build();
            order.getItems().add(orderItem);
            total = total.add(unitPrice.multiply(BigDecimal.valueOf(itemReq.getQuantity())));
        }
        order.setTotalAmount(total);
        Order saved = orderRepository.save(order);

        // Mutfak ve admin'e WebSocket bildirimi
        OrderResponse dto = toDto(saved);
        notificationService.publishToRestaurant(restaurant.getId(), "orders", dto);

        return dto;
    }

    /**
     * Mutfak: sipariş durumunu güncelle (PREPARING / READY).
     */
    @Transactional
    public OrderResponse updateStatus(Long orderId, OrderStatus newStatus) {
        Order order = findById(orderId);
        OrderStatus current = order.getStatus();

        // Geçerli durum geçişleri
        boolean valid = switch (current) {
            case PENDING -> newStatus == OrderStatus.PREPARING || newStatus == OrderStatus.CANCELLED;
            case PREPARING -> newStatus == OrderStatus.READY || newStatus == OrderStatus.CANCELLED;
            case READY -> newStatus == OrderStatus.DELIVERED;
            default -> false;
        };

        if (!valid) {
            throw new BusinessException("Geçersiz durum geçişi: " + current + " → " + newStatus);
        }

        order.setStatus(newStatus);
        if (newStatus == OrderStatus.READY) order.setReadyAt(LocalDateTime.now());
        if (newStatus == OrderStatus.DELIVERED) order.setDeliveredAt(LocalDateTime.now());
        Order saved = orderRepository.save(order);

        OrderResponse dto = toDto(saved);
        // Mutfak / admin
        notificationService.publishToRestaurant(order.getRestaurant().getId(), "orders", dto);
        // Müşteri
        notificationService.publishToSession(order.getTableSession().getSessionToken(), "status", dto);

        return dto;
    }

    /**
     * Mutfak: tek sipariş item öncelik sırasını güncelle.
     */
    @Transactional
    public void updateItemPriority(Long orderId, List<Long> itemIdsByPriority) {
        List<OrderItem> items = orderItemRepository.findByOrderId(orderId);
        for (int i = 0; i < itemIdsByPriority.size(); i++) {
            Long itemId = itemIdsByPriority.get(i);
            items.stream().filter(it -> it.getId().equals(itemId)).findFirst()
                    .ifPresent(it -> { it.setSortOrder(itemIdsByPriority.indexOf(itemId)); orderItemRepository.save(it); });
        }
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> getSessionOrders(String sessionToken) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        return orderRepository.findByTableSessionIdOrderByCreatedAtDesc(session.getId())
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> getKitchenOrders(Long restaurantId) {
        return orderRepository.findKitchenOrders(restaurantId)
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> getRestaurantOrders(Long restaurantId, OrderStatus status) {
        List<Order> orders = status != null
                ? orderRepository.findByRestaurantIdAndStatusOrderByCreatedAt(restaurantId, status)
                : orderRepository.findByRestaurantIdAndStatusIn(restaurantId, List.of(OrderStatus.values()));
        return orders.stream().map(this::toDto).toList();
    }

    public Order findById(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Order", id));
    }

    public OrderResponse toDto(Order o) {
        return OrderResponse.builder()
                .id(o.getId())
                .tableSessionId(o.getTableSession().getId())
                .tableId(o.getTableSession().getTable().getId())
                .tableNumber(o.getTableSession().getTable().getTableNumber())
                .status(o.getStatus())
                .totalAmount(o.getTotalAmount())
                .items(o.getItems().stream().map(this::toItemDto).toList())
                .createdAt(o.getCreatedAt())
                .updatedAt(o.getUpdatedAt())
                .readyAt(o.getReadyAt())
                .deliveredAt(o.getDeliveredAt())
                .estimatedMinutes(o.getItems().stream()
                        .mapToInt(i -> i.getMenuItem().getPreparationTimeMinutes())
                        .max().orElse(15))
                .build();
    }

    private OrderItemResponse toItemDto(OrderItem i) {
        return OrderItemResponse.builder()
                .id(i.getId())
                .menuItemId(i.getMenuItem().getId())
                .menuItemName(i.getMenuItem().getName())
                .menuItemNameEn(i.getMenuItem().getNameEn())
                .menuItemImageUrl(i.getMenuItem().getImageUrl())
                .quantity(i.getQuantity())
                .unitPrice(i.getUnitPrice())
                .note(i.getNote())
                .selectedNoteOptions(i.getSelectedNoteOptions())
                .status(i.getStatus())
                .sortOrder(i.getSortOrder())
                .build();
    }
}
