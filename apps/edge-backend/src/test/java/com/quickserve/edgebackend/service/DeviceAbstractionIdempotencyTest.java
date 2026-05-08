package com.quickserve.edgebackend.service;

import com.quickserve.edgebackend.device.PosChargeRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;

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
        var req = new PosChargeRequest("p1", new BigDecimal("10.00"), "TRY", "o1", "idem-replay-1");
        var first = deviceAbstractionService.charge(req, "mock-pos");
        assertFalse(first.idempotentReplay());

        var second = deviceAbstractionService.charge(req, "mock-pos");
        assertTrue(second.idempotentReplay());
        assertEquals(first.transactionId(), second.transactionId());
        assertEquals(first.success(), second.success());
    }

    @Test
    void conflictingPayloadWithSameIdempotencyKeyReturns409() {
        deviceAbstractionService.charge(
                new PosChargeRequest("p1", new BigDecimal("10.00"), "TRY", "o1", "idem-conflict-1"),
                "mock-pos");

        ResponseStatusException ex = assertThrows(
                ResponseStatusException.class,
                () -> deviceAbstractionService.charge(
                        new PosChargeRequest("p1", new BigDecimal("11.00"), "TRY", "o1", "idem-conflict-1"),
                        "mock-pos"));

        assertEquals(409, ex.getStatusCode().value());
    }
}
