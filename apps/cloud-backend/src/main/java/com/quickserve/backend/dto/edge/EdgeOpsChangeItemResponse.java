package com.quickserve.backend.dto.edge;

import lombok.Builder;

import java.time.Instant;

@Builder
public record EdgeOpsChangeItemResponse(
        long id,
        String eventId,
        String eventType,
        String aggregateType,
        String aggregateId,
        Instant eventTimestampUtc,
        String payloadJson
) {}
