package com.quickserve.edgebackend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class EdgeSyncWorkerService {

    private static final Logger log = LoggerFactory.getLogger(EdgeSyncWorkerService.class);

    private final EdgeSyncOutboxService outboxService;
    private final EdgeSyncInboxService inboxService;
    private final CloudBridgeService cloudBridgeService;
    private final EdgeInboxProcessorService inboxProcessorService;
    private final EdgeOutboxFlushTracker edgeOutboxFlushTracker;
    private final boolean workerEnabled;
    private final int batchSize;
    private final int maxRetry;
    private final int baseBackoffSeconds;

    public EdgeSyncWorkerService(
            EdgeSyncOutboxService outboxService,
            EdgeSyncInboxService inboxService,
            CloudBridgeService cloudBridgeService,
            EdgeInboxProcessorService inboxProcessorService,
            EdgeOutboxFlushTracker edgeOutboxFlushTracker,
            @Value("${app.edge.sync.worker-enabled:true}") boolean workerEnabled,
            @Value("${app.edge.sync.batch-size:50}") int batchSize,
            @Value("${app.edge.sync.max-retry:10}") int maxRetry,
            @Value("${app.edge.sync.base-backoff-seconds:5}") int baseBackoffSeconds
    ) {
        this.outboxService = outboxService;
        this.inboxService = inboxService;
        this.cloudBridgeService = cloudBridgeService;
        this.inboxProcessorService = inboxProcessorService;
        this.edgeOutboxFlushTracker = edgeOutboxFlushTracker;
        this.workerEnabled = workerEnabled;
        this.batchSize = batchSize;
        this.maxRetry = maxRetry;
        this.baseBackoffSeconds = baseBackoffSeconds;
    }

    @Scheduled(fixedDelayString = "${app.edge.sync.interval-ms:5000}")
    public void processOutbox() {
        if (!workerEnabled) {
            return;
        }

        processInboxRetries();

        if (cloudBridgeService.shouldTryCloudLive()) {
            List<EdgeSyncOutboxService.OutboxEvent> events = outboxService.pollPendingEvents(batchSize);
            for (EdgeSyncOutboxService.OutboxEvent event : events) {
                handleEvent(event);
            }
        }
    }

    private void processInboxRetries() {
        List<EdgeSyncInboxService.InboxEvent> events = inboxService.pollRetryableEvents(batchSize);
        for (EdgeSyncInboxService.InboxEvent event : events) {
            EdgeInboxProcessorService.ProcessResult result = inboxProcessorService.process(
                    event.sourceEventId(),
                    event.sourceSystem(),
                    event.payloadJson(),
                    false
            );
            if ("dead".equals(result.status())) {
                log.error("Inbox event moved to DEAD. sourceEventId={}, retries={}",
                        result.sourceEventId(), result.retryCount());
            } else if ("retry_scheduled".equals(result.status())) {
                log.warn("Inbox event retry re-scheduled. sourceEventId={}, retries={}, backoff={}s",
                        result.sourceEventId(), result.retryCount(), result.backoffSeconds());
            }
        }
    }

    private void handleEvent(EdgeSyncOutboxService.OutboxEvent event) {
        try {
            cloudBridgeService.pushEdgeEvent(event.id(), event.eventType(), event.payloadJson());
            outboxService.markSent(event.id());
            edgeOutboxFlushTracker.recordSuccessfulFlush();
        } catch (Exception ex) {
            int nextRetryCount = event.retryCount() + 1;
            String reason = abbreviate(ex.getMessage());
            if (nextRetryCount >= maxRetry) {
                outboxService.markDead(event.id(), nextRetryCount, reason);
                log.error("Outbox event moved to DEAD. eventId={}, retries={}", event.id(), nextRetryCount);
                return;
            }

            int backoffSeconds = calculateBackoffSeconds(nextRetryCount);
            outboxService.markRetry(event.id(), nextRetryCount, backoffSeconds, reason);
            log.warn("Outbox event retry scheduled. eventId={}, retries={}, backoff={}s",
                    event.id(), nextRetryCount, backoffSeconds);
        }
    }

    private int calculateBackoffSeconds(int retryCount) {
        long backoff = (long) baseBackoffSeconds * (1L << Math.min(retryCount, 8));
        return (int) Math.min(backoff, 3600L);
    }

    private String abbreviate(String message) {
        if (message == null || message.isBlank()) {
            return "bridge_push_failed";
        }
        return message.length() > 400 ? message.substring(0, 400) : message;
    }
}
