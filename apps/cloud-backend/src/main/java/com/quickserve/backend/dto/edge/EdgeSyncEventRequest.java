package com.quickserve.backend.dto.edge;

import jakarta.validation.constraints.NotBlank;

public record EdgeSyncEventRequest(
        @NotBlank String eventId,
        @NotBlank String eventType,
        String payloadJson,
        /** Lab (JWT yok): edge node restoran bağlamı; yalnızca kapalı lab cloud ile anlamlı. */
        Long restaurantId
) {}
