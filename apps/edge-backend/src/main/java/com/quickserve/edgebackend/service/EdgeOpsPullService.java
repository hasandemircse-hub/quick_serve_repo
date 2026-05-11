package com.quickserve.edgebackend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class EdgeOpsPullService {

    private static final Logger log = LoggerFactory.getLogger(EdgeOpsPullService.class);

    private final CloudBridgeService cloudBridgeService;
    private final EdgeOpsLocalCacheService edgeOpsLocalCacheService;
    private final ObjectMapper objectMapper;

    @Value("${app.edge.restaurant-id:0}")
    private long restaurantId;

    @Value("${app.edge.ops-pull-enabled:true}")
    private boolean opsPullEnabled;

    public EdgeOpsPullService(
            CloudBridgeService cloudBridgeService,
            EdgeOpsLocalCacheService edgeOpsLocalCacheService,
            ObjectMapper objectMapper
    ) {
        this.cloudBridgeService = cloudBridgeService;
        this.edgeOpsLocalCacheService = edgeOpsLocalCacheService;
        this.objectMapper = objectMapper;
    }

    @Scheduled(fixedDelayString = "${app.edge.ops-pull-interval-ms:10000}")
    public void scheduledPull() {
        pullInternal(1);
    }

    /** Cloud WS edge_ops sinyali sonrası gap-fill. */
    public void pullAfterWsHint() {
        pullInternal(3);
    }

    private void pullInternal(int maxRounds) {
        if (!opsPullEnabled || !cloudBridgeService.shouldTryCloudLive() || restaurantId <= 0) {
            return;
        }
        for (int round = 0; round < maxRounds; round++) {
            long since = edgeOpsLocalCacheService.getOpsChangesCursor();
            String raw = cloudBridgeService.fetchOpsChangesRaw(since, 100);
            if (raw == null || raw.isBlank()) {
                return;
            }
            try {
                JsonNode root = objectMapper.readTree(raw);
                JsonNode events = root.path("events");
                if (!events.isArray() || events.size() == 0) {
                    long nextSince = root.path("nextSince").asLong(since);
                    if (nextSince > since) {
                        edgeOpsLocalCacheService.setOpsChangesCursor(nextSince);
                    }
                    return;
                }
                long maxSeen = since;
                for (JsonNode e : events) {
                    long id = e.path("id").asLong();
                    maxSeen = Math.max(maxSeen, id);
                    String eventId = e.path("eventId").asText();
                    String eventType = e.path("eventType").asText();
                    String payloadJson = e.path("payloadJson").isMissingNode()
                            ? ""
                            : e.path("payloadJson").asText("");
                    if (!eventType.isBlank()) {
                        edgeOpsLocalCacheService.applyCloudReplay(eventType, payloadJson, eventId);
                    }
                }
                long nextSince = root.path("nextSince").asLong(maxSeen);
                edgeOpsLocalCacheService.setOpsChangesCursor(Math.max(nextSince, maxSeen));
                if (events.size() < 100) {
                    return;
                }
            } catch (Exception ex) {
                log.warn("edge ops pull parse failed: {}", ex.getMessage());
                return;
            }
        }
    }
}
