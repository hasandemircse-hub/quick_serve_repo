package com.quickserve.backend.edge;

import com.quickserve.backend.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * Cloud'da master veri (masa, menü, personel vb.) değişince edge'lere WS ile sinyal gönderir.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EdgeMasterDataChangedPublisher {

    public static final String WS_TOPIC_SUFFIX = "edge_master";

    private final NotificationService notificationService;

    public void publish(Long restaurantId, String reason) {
        if (restaurantId == null || restaurantId <= 0) {
            return;
        }
        Map<String, Object> payload = new HashMap<>();
        payload.put("event", "SNAPSHOT_INVALIDATED");
        payload.put("reason", reason != null ? reason : "unknown");
        payload.put("occurredAt", Instant.now().toString());
        try {
            notificationService.publishToRestaurant(restaurantId, WS_TOPIC_SUFFIX, payload);
        } catch (Exception e) {
            log.warn("edge_master WS publish failed restaurantId={}: {}", restaurantId, e.getMessage());
        }
    }
}
