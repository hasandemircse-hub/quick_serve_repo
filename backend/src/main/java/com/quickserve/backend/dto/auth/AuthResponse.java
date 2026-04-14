package com.quickserve.backend.dto.auth;

import com.quickserve.backend.enums.UserRole;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AuthResponse {
    private String token;
    private String username;
    private String fullName;
    private UserRole role;
    private Long restaurantId;
    private String restaurantName;
    private Long userId;
}
