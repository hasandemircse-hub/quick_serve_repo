package com.quickserve.backend.dto.edge;

import jakarta.validation.constraints.NotBlank;

public record EdgeSyncEventRequest(
        @NotBlank String eventId,
        @NotBlank String eventType,
        String payloadJson
) {}
