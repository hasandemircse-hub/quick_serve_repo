package com.quickserve.backend.dto.edge;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Jackson + Lombok builder birleşiminde köprü alanının bazen JSON'dan düşmesi riskine karşı record kullanılıyor.
 */
public record EdgeEnrollmentClaimResponse(
        Long restaurantId,
        EdgeNodeResponse edgeNode,
        @JsonProperty("bridgeJwtToken") String bridgeJwtToken
) {}
