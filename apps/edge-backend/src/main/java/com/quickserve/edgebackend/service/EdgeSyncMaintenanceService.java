package com.quickserve.edgebackend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

@Service
public class EdgeSyncMaintenanceService {

    private static final Logger log = LoggerFactory.getLogger(EdgeSyncMaintenanceService.class);

    private final EdgeSyncOutboxService outboxService;
    private final EdgeSyncInboxService inboxService;
    private final EdgePosChargeAuditService posChargeAuditService;
    private final boolean enabled;
    private final int sentRetentionDays;
    private final int deadRetentionDays;
    private final int inboxProcessedRetentionDays;
    private final int inboxDeadRetentionDays;
    private final int posAuditRetentionDays;

    public EdgeSyncMaintenanceService(
            EdgeSyncOutboxService outboxService,
            EdgeSyncInboxService inboxService,
            EdgePosChargeAuditService posChargeAuditService,
            @Value("${app.edge.sync.maintenance.enabled:true}") boolean enabled,
            @Value("${app.edge.sync.retention.sent-days:3}") int sentRetentionDays,
            @Value("${app.edge.sync.retention.dead-days:14}") int deadRetentionDays,
            @Value("${app.edge.sync.retention.inbox-processed-days:7}") int inboxProcessedRetentionDays,
            @Value("${app.edge.sync.retention.inbox-dead-days:14}") int inboxDeadRetentionDays,
            @Value("${app.edge.device.pos.audit.retention-days:90}") int posAuditRetentionDays
    ) {
        this.outboxService = outboxService;
        this.inboxService = inboxService;
        this.posChargeAuditService = posChargeAuditService;
        this.enabled = enabled;
        this.sentRetentionDays = sentRetentionDays;
        this.deadRetentionDays = deadRetentionDays;
        this.inboxProcessedRetentionDays = inboxProcessedRetentionDays;
        this.inboxDeadRetentionDays = inboxDeadRetentionDays;
        this.posAuditRetentionDays = posAuditRetentionDays;
    }

    @Scheduled(fixedDelayString = "${app.edge.sync.maintenance.interval-ms:3600000}")
    public void cleanupSyncQueues() {
        if (!enabled) {
            return;
        }

        int deletedOutboxSent = outboxService.purgeSentOlderThanDays(sentRetentionDays);
        int deletedOutboxDead = outboxService.purgeDeadOlderThanDays(deadRetentionDays);
        int deletedInboxProcessed = inboxService.purgeProcessedOlderThanDays(inboxProcessedRetentionDays);
        int deletedInboxDead = inboxService.purgeDeadOlderThanDays(inboxDeadRetentionDays);
        int deletedPosAudit = posAuditRetentionDays > 0
                ? posChargeAuditService.purgeOlderThanDays(posAuditRetentionDays)
                : 0;

        if (deletedOutboxSent + deletedOutboxDead + deletedInboxProcessed + deletedInboxDead + deletedPosAudit > 0) {
            log.info(
                    "Edge sync cleanup done. outboxSentDeleted={}, outboxDeadDeleted={}, inboxProcessedDeleted={}, inboxDeadDeleted={}, posAuditDeleted={}",
                    deletedOutboxSent,
                    deletedOutboxDead,
                    deletedInboxProcessed,
                    deletedInboxDead,
                    deletedPosAudit
            );
        }
    }
}
