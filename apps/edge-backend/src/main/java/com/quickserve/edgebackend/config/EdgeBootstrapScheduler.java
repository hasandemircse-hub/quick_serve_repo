package com.quickserve.edgebackend.config;

import com.quickserve.edgebackend.service.EdgeBootstrapSyncService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.Scheduled;

@Configuration
public class EdgeBootstrapScheduler implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(EdgeBootstrapScheduler.class);

    private final EdgeBootstrapSyncService bootstrapSyncService;
    private final boolean pullOnStartup;

    public EdgeBootstrapScheduler(
            EdgeBootstrapSyncService bootstrapSyncService,
            @Value("${app.edge.bootstrap.pull-on-startup:true}") boolean pullOnStartup
    ) {
        this.bootstrapSyncService = bootstrapSyncService;
        this.pullOnStartup = pullOnStartup;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!pullOnStartup) {
            return;
        }
        try {
            Thread.sleep(1500L);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        if (bootstrapSyncService.pullSnapshotFromCloud()) {
            log.info("Edge bootstrap: initial snapshot pull completed");
        }
    }

    @Scheduled(fixedDelayString = "${app.edge.bootstrap.pull-interval-ms:900000}")
    public void periodicSnapshotPull() {
        bootstrapSyncService.pullSnapshotFromCloud();
    }
}
