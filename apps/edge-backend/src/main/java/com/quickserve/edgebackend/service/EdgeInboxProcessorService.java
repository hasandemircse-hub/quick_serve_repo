package com.quickserve.edgebackend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class EdgeInboxProcessorService {

    private final EdgeSyncInboxService inboxService;
    private final int maxRetry;
    private final int baseBackoffSeconds;

    public EdgeInboxProcessorService(
            EdgeSyncInboxService inboxService,
            @Value("${app.edge.sync.max-retry:10}") int maxRetry,
            @Value("${app.edge.sync.base-backoff-seconds:5}") int baseBackoffSeconds
    ) {
        this.inboxService = inboxService;
        this.maxRetry = maxRetry;
        this.baseBackoffSeconds = baseBackoffSeconds;
    }

    public ProcessResult process(String sourceEventId, String sourceSystem, String payloadJson, boolean saveIfNew) {
        if (saveIfNew) {
            boolean inserted = inboxService.saveIfNew(sourceEventId, sourceSystem, payloadJson);
            if (!inserted) {
                return ProcessResult.duplicateIgnored(sourceEventId);
            }
        }

        try {
            applyDomainEvent(payloadJson);
            inboxService.markProcessed(sourceEventId, sourceSystem);
            return ProcessResult.processed(sourceEventId);
        } catch (Exception ex) {
            int retryCount = inboxService.getRetryCount(sourceEventId, sourceSystem) + 1;
            String reason = abbreviate(ex.getMessage());
            if (retryCount >= maxRetry) {
                inboxService.markDead(sourceEventId, sourceSystem, retryCount, reason);
                return ProcessResult.dead(sourceEventId, retryCount);
            }

            int backoffSeconds = calculateBackoffSeconds(retryCount);
            inboxService.markRetry(sourceEventId, sourceSystem, retryCount, backoffSeconds, reason);
            return ProcessResult.retryScheduled(sourceEventId, retryCount, backoffSeconds);
        }
    }

    private void applyDomainEvent(String payloadJson) {
        if (payloadJson != null && payloadJson.contains("\"forceFail\":true")) {
            throw new IllegalStateException("forced_domain_apply_failure");
        }
    }

    private int calculateBackoffSeconds(int retryCount) {
        long backoff = (long) baseBackoffSeconds * (1L << Math.min(retryCount, 8));
        return (int) Math.min(backoff, 3600L);
    }

    private String abbreviate(String message) {
        if (message == null || message.isBlank()) {
            return "inbox_apply_failed";
        }
        return message.length() > 400 ? message.substring(0, 400) : message;
    }

    public record ProcessResult(String status, String sourceEventId, Integer retryCount, Integer backoffSeconds) {
        public static ProcessResult duplicateIgnored(String sourceEventId) {
            return new ProcessResult("duplicate_ignored", sourceEventId, null, null);
        }

        public static ProcessResult processed(String sourceEventId) {
            return new ProcessResult("processed", sourceEventId, null, null);
        }

        public static ProcessResult retryScheduled(String sourceEventId, int retryCount, int backoffSeconds) {
            return new ProcessResult("retry_scheduled", sourceEventId, retryCount, backoffSeconds);
        }

        public static ProcessResult dead(String sourceEventId, int retryCount) {
            return new ProcessResult("dead", sourceEventId, retryCount, null);
        }
    }
}
