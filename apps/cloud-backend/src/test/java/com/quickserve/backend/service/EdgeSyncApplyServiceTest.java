package com.quickserve.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.quickserve.backend.entity.EdgeSyncReceivedEvent;
import com.quickserve.backend.entity.Order;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.repository.EdgeSyncReceivedEventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EdgeSyncApplyServiceTest {

    @Mock
    EdgeSyncReceivedEventRepository receivedEventRepository;
    @Mock
    OrderService orderService;
    @Mock
    WaiterCallService waiterCallService;
    @Mock
    PaymentService paymentService;
    @Mock
    NotificationService notificationService;

    EdgeSyncApplyService edgeSyncApplyService;

    @BeforeEach
    void setUp() {
        edgeSyncApplyService = new EdgeSyncApplyService(
                receivedEventRepository,
                orderService,
                waiterCallService,
                paymentService,
                notificationService,
                new ObjectMapper()
        );
    }

    @Test
    void duplicateEventId_skipsEverything() {
        when(receivedEventRepository.existsByEventId("e1")).thenReturn(true);
        edgeSyncApplyService.apply("e1", "ORDER_STATUS_UPDATED", "{}", 1L);
        verifyNoInteractions(orderService);
        verify(receivedEventRepository, never()).save(any());
    }

    @Test
    void olderThanApplied_discardsAndRecords() {
        when(receivedEventRepository.existsByEventId("e-old")).thenReturn(false);
        when(receivedEventRepository.findMaxAppliedEventTimestamp(1L, "ORDER", "42"))
                .thenReturn(Optional.of(Instant.parse("2025-02-02T00:00:00Z")));
        String payload = """
                {"orderId":"42","status":"PREPARING","eventTimestampUtc":"2025-02-01T00:00:00Z"}
                """;
        edgeSyncApplyService.apply("e-old", "ORDER_STATUS_UPDATED", payload, 1L);

        verify(orderService, never()).updateStatus(anyLong(), any(OrderStatus.class));
        ArgumentCaptor<EdgeSyncReceivedEvent> cap = ArgumentCaptor.forClass(EdgeSyncReceivedEvent.class);
        verify(receivedEventRepository).save(cap.capture());
        assertThat(cap.getValue().isApplied()).isFalse();
        assertThat(cap.getValue().getDiscardedReason()).isEqualTo("OLDER_THAN_APPLIED");
        verify(notificationService).publishToRestaurant(eq(1L), eq("edge_ops"), any());
    }

    @Test
    void appliesOrderStatusWhenFresh() {
        when(receivedEventRepository.existsByEventId("e2")).thenReturn(false);
        when(receivedEventRepository.findMaxAppliedEventTimestamp(1L, "ORDER", "7")).thenReturn(Optional.empty());
        Order order = Order.builder().id(7L).restaurant(Restaurant.builder().id(1L).build()).build();
        when(orderService.findById(7L)).thenReturn(order);

        String payload = """
                {"orderId":"7","status":"PREPARING","eventTimestampUtc":"2025-03-01T12:00:00Z"}
                """;
        edgeSyncApplyService.apply("e2", "ORDER_STATUS_UPDATED", payload, 1L);

        verify(orderService).updateStatus(7L, OrderStatus.PREPARING);
        ArgumentCaptor<EdgeSyncReceivedEvent> cap = ArgumentCaptor.forClass(EdgeSyncReceivedEvent.class);
        verify(receivedEventRepository).save(cap.capture());
        assertThat(cap.getValue().isApplied()).isTrue();
        verify(notificationService).publishToRestaurant(eq(1L), eq("edge_ops"), any());
    }
}
