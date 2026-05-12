package com.quickserve.edgebackend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class EdgeHeartbeatScheduler {

    private static final Logger log = LoggerFactory.getLogger(EdgeHeartbeatScheduler.class);

    private final CloudBridgeService cloudBridgeService;
    private final EdgeOutboxFlushTracker edgeOutboxFlushTracker;
    private final EdgeCloudLinkTracker edgeCloudLinkTracker;

    @Value("${app.edge.heartbeat-enabled:true}")
    private boolean heartbeatEnabled;

    @Value("${app.edge.restaurant-id:0}")
    private long restaurantId;

    @Value("${app.edge.node-id:edge-local}")
    private String nodeId;

    public EdgeHeartbeatScheduler(
            CloudBridgeService cloudBridgeService,
            EdgeOutboxFlushTracker edgeOutboxFlushTracker,
            EdgeCloudLinkTracker edgeCloudLinkTracker) {
        this.cloudBridgeService = cloudBridgeService;
        this.edgeOutboxFlushTracker = edgeOutboxFlushTracker;
        this.edgeCloudLinkTracker = edgeCloudLinkTracker;
    }

    @Scheduled(fixedDelayString = "${app.edge.heartbeat-interval-ms:30000}")
    public void sendHeartbeat() {
        if (!heartbeatEnabled || !cloudBridgeService.shouldTryCloudLive() || restaurantId <= 0) {
            return;
        }
        if (nodeId == null || nodeId.isBlank()) {
            return;
        }
        edgeCloudLinkTracker.recordHeartbeatAttempt();
        try {
            cloudBridgeService.postHeartbeat(restaurantId, nodeId, edgeOutboxFlushTracker.lastFlushIso());
            edgeCloudLinkTracker.recordHeartbeatSuccess();
        } catch (Exception ex) {
            edgeCloudLinkTracker.recordHeartbeatFailure(ex.getMessage());
            log.debug("edge heartbeat failed: {}", ex.getMessage());
        }
    }
}
