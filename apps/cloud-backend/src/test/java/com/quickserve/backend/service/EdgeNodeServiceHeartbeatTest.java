package com.quickserve.backend.service;

import com.quickserve.backend.dto.edge.EdgeNodeResponse;
import com.quickserve.backend.entity.EdgeNode;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.enums.EdgeNodeStatus;
import com.quickserve.backend.repository.EdgeNodeRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EdgeNodeServiceHeartbeatTest {

    @Mock
    EdgeNodeRepository edgeNodeRepository;
    @Mock
    RestaurantService restaurantService;
    @Mock
    NotificationService notificationService;

    @InjectMocks
    EdgeNodeService edgeNodeService;

    @Test
    void heartbeat_updatesNodeAndPublishesWs() {
        Restaurant restaurant = Restaurant.builder().id(3L).build();
        EdgeNode node = EdgeNode.builder()
                .id(9L)
                .restaurant(restaurant)
                .nodeName("edge-box-1")
                .deviceType("MINI_PC")
                .localIp("10.0.0.2")
                .status(EdgeNodeStatus.OFFLINE)
                .isActive(true)
                .lastSeenAt(LocalDateTime.of(2020, 1, 1, 0, 0))
                .lastSyncAt(null)
                .build();

        when(edgeNodeRepository.findFirstByRestaurant_IdAndNodeName(3L, "edge-box-1")).thenReturn(Optional.of(node));
        when(edgeNodeRepository.save(any(EdgeNode.class))).thenAnswer(inv -> inv.getArgument(0));

        EdgeNodeResponse dto = edgeNodeService.recordHeartbeat(3L, "edge-box-1", "2025-05-10T08:30:00Z");

        assertThat(dto.getStatus()).isEqualTo(EdgeNodeStatus.ONLINE);
        assertThat(dto.getLastSeenAt()).isNotNull();
        assertThat(dto.getLastSyncAt()).isNotNull();
        assertThat(dto.getEffectiveOnline()).isTrue();
        verify(notificationService).publishToRestaurant(eq(3L), eq("edge_nodes"), anyMap());
    }
}
