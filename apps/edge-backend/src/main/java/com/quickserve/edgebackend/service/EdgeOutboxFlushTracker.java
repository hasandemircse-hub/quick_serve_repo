package com.quickserve.edgebackend.service;

import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;

@Component
public class EdgeOutboxFlushTracker {

    private final AtomicReference<Instant> lastSuccessfulFlush = new AtomicReference<>();

    public void recordSuccessfulFlush() {
        lastSuccessfulFlush.set(Instant.now());
    }

    /** ISO-8601 veya null */
    public String lastFlushIso() {
        Instant v = lastSuccessfulFlush.get();
        return v == null ? null : v.toString();
    }
}
