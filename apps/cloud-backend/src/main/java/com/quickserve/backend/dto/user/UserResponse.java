package com.quickserve.backend.dto.user;

import com.quickserve.backend.enums.UserRole;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class UserResponse {
    private Long id;
    private String username;
    private String fullName;
    private String email;
    private String phone;
    private UserRole role;
    private Boolean isActive;
    private Boolean isOnLeave;
    private String leaveReason;
    private Long restaurantId;
    private LocalDateTime createdAt;
    private LocalDateTime lastLoginAt;
}
