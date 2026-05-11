package com.quickserve.backend.dto.edge;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Edge cihazından cloud'a periyodik durum (lab modunda restaurantId zorunlu).
 */
public record EdgeHeartbeatRequest(
        @NotNull Long restaurantId,
        @NotBlank String nodeName,
        /** ISO-8601; outbox başarılı flush zamanı — varsa EdgeNode.lastSyncAt güncellenir. */
        String lastOutboxFlushAtUtc
) {}
