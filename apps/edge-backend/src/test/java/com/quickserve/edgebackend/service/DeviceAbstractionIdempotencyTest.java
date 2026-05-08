package com.quickserve.edgebackend.service;

import com.quickserve.edgebackend.device.PosChargeRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest(properties = {
        "EDGE_SQLITE_PATH=./target/edge-idem-test.db"
})
class DeviceAbstractionIdempotencyTest {

    @Autowired
    private DeviceAbstractionService deviceAbstractionService;

    @Test
    void sameIdempotencyKeyReplaysCachedResult() {
        String idemKey = "idem-replay-" + UUID.randomUUID();
        var req = new PosChargeRequest("p1", new BigDecimal("10.00"), "TRY", "o1", idemKey);
        var first = deviceAbstractionService.charge(req, "mock-pos");
        assertFalse(first.idempotentReplay());

        var second = deviceAbstractionService.charge(req, "mock-pos");
        assertTrue(second.idempotentReplay());
        assertEquals(first.transactionId(), second.transactionId());
        assertEquals(first.success(), second.success());
    }

    @Test
    void conflictingPayloadWithSameIdempotencyKeyReturns409() {
        String idemKey = "idem-conflict-" + UUID.randomUUID();
        deviceAbstractionService.charge(
                new PosChargeRequest("p1", new BigDecimal("10.00"), "TRY", "o1", idemKey),
                "mock-pos");

        ResponseStatusException ex = assertThrows(
                ResponseStatusException.class,
                () -> deviceAbstractionService.charge(
                        new PosChargeRequest("p1", new BigDecimal("11.00"), "TRY", "o1", idemKey),
                        "mock-pos"));

        assertEquals(409, ex.getStatusCode().value());
    }
}
