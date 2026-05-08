package com.quickserve.backend.dto.session;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class SessionResponse {
    private Long sessionId;
    private String sessionToken;
    private Long tableId;
    private String tableNumber;
    private Long restaurantId;
    private String restaurantName;
    private String restaurantLogoUrl;
    private String restaurantPrimaryColor;
    private LocalDateTime openedAt;
    private Boolean isActive;
}
