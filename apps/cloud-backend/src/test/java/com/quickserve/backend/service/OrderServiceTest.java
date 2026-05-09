package com.quickserve.backend.service;

import com.quickserve.backend.dto.order.OrderItemRequest;
import com.quickserve.backend.dto.order.OrderRequest;
import com.quickserve.backend.dto.order.OrderResponse;
import com.quickserve.backend.entity.*;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.enums.TableStatus;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock OrderRepository orderRepository;
    @Mock OrderItemRepository orderItemRepository;
    @Mock TableSessionRepository sessionRepository;
    @Mock MenuService menuService;
    @Mock NotificationService notificationService;

    @InjectMocks OrderService orderService;

    private TableSession activeSession;
    private MenuItem menuItem;

    @BeforeEach
    void setup() {
        Restaurant restaurant = Restaurant.builder().id(1L).name("Test Restaurant").build();
        RestaurantTable table = RestaurantTable.builder()
                .id(1L).restaurant(restaurant).tableNumber("1").status(TableStatus.OCCUPIED).build();
        activeSession = TableSession.builder()
                .id(1L).table(table).sessionToken("test-token").isActive(true).build();

        menuItem = MenuItem.builder()
                .id(1L).restaurant(restaurant).name("Burger")
                .price(BigDecimal.valueOf(50)).isAvailable(true).isRemoved(false)
                .isCampaign(false).preparationTimeMinutes(15).noteOptions(new ArrayList<>()).build();
    }

    @Test
    void createOrder_success() {
        OrderItemRequest itemReq = new OrderItemRequest();
        itemReq.setMenuItemId(1L);
        itemReq.setQuantity(2);

        OrderRequest req = new OrderRequest();
        req.setItems(List.of(itemReq));

        when(sessionRepository.findBySessionToken("test-token")).thenReturn(Optional.of(activeSession));
        when(menuService.findItemById(1L)).thenReturn(menuItem);

        Order savedOrder = Order.builder()
                .id(1L).tableSession(activeSession).restaurant(activeSession.getTable().getRestaurant())
                .status(OrderStatus.PENDING).totalAmount(BigDecimal.valueOf(100)).items(new ArrayList<>()).build();
        when(orderRepository.save(any())).thenReturn(savedOrder);

        OrderResponse response = orderService.createOrder("test-token", req);

        assertThat(response).isNotNull();
        assertThat(response.getStatus()).isEqualTo(OrderStatus.PENDING);
    }

    @Test
    void createOrder_inactiveSession_throwsBusiness() {
        activeSession.setIsActive(false);
        when(sessionRepository.findBySessionToken("test-token")).thenReturn(Optional.of(activeSession));

        OrderRequest req = new OrderRequest();
        req.setItems(List.of());

        assertThatThrownBy(() -> orderService.createOrder("test-token", req))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    void createOrderForSession_success() {
        OrderItemRequest itemReq = new OrderItemRequest();
        itemReq.setMenuItemId(1L);
        itemReq.setQuantity(2);

        OrderRequest req = new OrderRequest();
        req.setItems(List.of(itemReq));

        when(sessionRepository.findById(1L)).thenReturn(Optional.of(activeSession));
        when(menuService.findItemById(1L)).thenReturn(menuItem);

        Order savedOrder = Order.builder()
                .id(2L).tableSession(activeSession).restaurant(activeSession.getTable().getRestaurant())
                .status(OrderStatus.PENDING).totalAmount(BigDecimal.valueOf(100)).items(new ArrayList<>()).build();
        when(orderRepository.save(any())).thenReturn(savedOrder);

        OrderResponse response = orderService.createOrderForSession(1L, req);

        assertThat(response).isNotNull();
        assertThat(response.getStatus()).isEqualTo(OrderStatus.PENDING);
    }

    @Test
    void createOrder_unavailableItem_throwsBusiness() {
        menuItem.setIsAvailable(false);
        OrderItemRequest itemReq = new OrderItemRequest();
        itemReq.setMenuItemId(1L);
        itemReq.setQuantity(1);

        OrderRequest req = new OrderRequest();
        req.setItems(List.of(itemReq));

        when(sessionRepository.findBySessionToken("test-token")).thenReturn(Optional.of(activeSession));
        when(menuService.findItemById(1L)).thenReturn(menuItem);

        assertThatThrownBy(() -> orderService.createOrder("test-token", req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("mevcut değil");
    }

    @Test
    void updateStatus_invalidTransition_throwsBusiness() {
        Order order = Order.builder()
                .id(1L).tableSession(activeSession)
                .restaurant(activeSession.getTable().getRestaurant())
                .status(OrderStatus.DELIVERED).items(new ArrayList<>()).build();
        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

        assertThatThrownBy(() -> orderService.updateStatus(1L, OrderStatus.PREPARING))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Geçersiz durum geçişi");
    }
}
