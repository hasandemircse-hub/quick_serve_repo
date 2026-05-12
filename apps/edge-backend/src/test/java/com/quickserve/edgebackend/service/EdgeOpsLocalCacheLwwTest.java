package com.quickserve.edgebackend.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(properties = {
        "EDGE_SQLITE_PATH=./target/edge-ops-lww-test.db",
        "app.edge.ops-pull-enabled=false",
        "app.edge.heartbeat-enabled=false",
        "app.edge.sync.worker-enabled=false",
        "app.edge.cloud-ws-enabled=false"
})
class EdgeOpsLocalCacheLwwTest {

    @Autowired
    EdgeOpsLocalCacheService edgeOpsLocalCacheService;

    @Autowired
    JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanOrders() {
        jdbcTemplate.update("DELETE FROM edge_ops_order");
    }

    @Test
    void cloudReplay_rejectsOlderTimestamp() {
        String newer = """
                {"orderId":"10","status":"READY","eventTimestampUtc":"2025-01-02T12:00:00Z"}
                """;
        edgeOpsLocalCacheService.applyCloudReplay("ORDER_STATUS_UPDATED", newer, "evt-" + UUID.randomUUID());
        assertEquals(Optional.of("READY"), edgeOpsLocalCacheService.getOrderStatus("10"));

        String older = """
                {"orderId":"10","status":"PREPARING","eventTimestampUtc":"2025-01-01T12:00:00Z"}
                """;
        edgeOpsLocalCacheService.applyCloudReplay("ORDER_STATUS_UPDATED", older, "evt-" + UUID.randomUUID());
        assertEquals(Optional.of("READY"), edgeOpsLocalCacheService.getOrderStatus("10"));
    }

    @Test
    void localWrite_alwaysOverridesForResponsiveUi() {
        String older = """
                {"orderId":"11","status":"PREPARING","eventTimestampUtc":"2025-01-01T12:00:00Z"}
                """;
        edgeOpsLocalCacheService.applyCloudReplay("ORDER_STATUS_UPDATED", older, "a");
        String newerLocal = """
                {"orderId":"11","status":"READY","eventTimestampUtc":"2025-01-01T11:00:00Z"}
                """;
        edgeOpsLocalCacheService.applyLocalWrite("ORDER_STATUS_UPDATED", newerLocal, "local-1");
        assertEquals(Optional.of("READY"), edgeOpsLocalCacheService.getOrderStatus("11"));
    }
}
