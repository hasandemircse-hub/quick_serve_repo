package com.quickserve.edgebackend.service;

import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Cloud'a heartbeat denemelerinin sonucunu UI ve tanı için tutar.
 */
@Component
public class EdgeCloudLinkTracker {

    private final AtomicReference<Instant> lastHeartbeatSuccessAt = new AtomicReference<>();
    private final AtomicReference<Instant> lastHeartbeatAttemptAt = new AtomicReference<>();
    private final AtomicReference<String> lastHeartbeatError = new AtomicReference<>();

    public void recordHeartbeatAttempt() {
        lastHeartbeatAttemptAt.set(Instant.now());
    }

    public void recordHeartbeatSuccess() {
        lastHeartbeatSuccessAt.set(Instant.now());
        lastHeartbeatError.set(null);
    }

    public void recordHeartbeatFailure(String message) {
        lastHeartbeatError.set(message == null || message.isBlank() ? "unknown" : message);
    }

    public Instant getLastHeartbeatSuccessAt() {
        return lastHeartbeatSuccessAt.get();
    }

    public Instant getLastHeartbeatAttemptAt() {
        return lastHeartbeatAttemptAt.get();
    }

    public String getLastHeartbeatError() {
        return lastHeartbeatError.get();
    }
}
