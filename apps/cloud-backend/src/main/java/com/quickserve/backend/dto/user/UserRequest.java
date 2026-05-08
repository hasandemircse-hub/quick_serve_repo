package com.quickserve.backend.dto.user;

import com.quickserve.backend.enums.UserRole;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class UserRequest {
    @NotBlank
    private String username;
    @NotBlank
    private String password;
    private String fullName;
    private String email;
    private String phone;
    @NotNull
    private UserRole role;
}
