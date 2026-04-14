package com.quickserve.backend.service;

import com.quickserve.backend.dto.auth.AuthResponse;
import com.quickserve.backend.dto.auth.LoginRequest;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.exception.UnauthorizedException;
import com.quickserve.backend.repository.UserRepository;
import com.quickserve.backend.security.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock AuthenticationManager authenticationManager;
    @Mock UserRepository userRepository;
    @Mock JwtUtil jwtUtil;
    @Mock AuditService auditService;

    @InjectMocks AuthService authService;

    private User activeUser;

    @BeforeEach
    void setup() {
        activeUser = User.builder()
                .id(1L).username("testuser").passwordHash("hashed")
                .role(UserRole.WAITER).isActive(true).isOnLeave(false).build();
    }

    @Test
    void login_success_returnsToken() {
        LoginRequest req = new LoginRequest();
        req.setUsername("testuser");
        req.setPassword("password");

        when(userRepository.findByUsername("testuser")).thenReturn(Optional.of(activeUser));
        when(jwtUtil.generateToken(activeUser)).thenReturn("jwt-token");
        when(userRepository.save(any())).thenReturn(activeUser);

        AuthResponse response = authService.login(req, "127.0.0.1");

        assertThat(response.getToken()).isEqualTo("jwt-token");
        assertThat(response.getRole()).isEqualTo(UserRole.WAITER);
    }

    @Test
    void login_wrongPassword_throwsUnauthorized() {
        LoginRequest req = new LoginRequest();
        req.setUsername("testuser");
        req.setPassword("wrong");

        doThrow(new BadCredentialsException("bad"))
                .when(authenticationManager).authenticate(any(UsernamePasswordAuthenticationToken.class));

        assertThatThrownBy(() -> authService.login(req, "127.0.0.1"))
                .isInstanceOf(UnauthorizedException.class);
    }

    @Test
    void login_inactiveUser_throwsUnauthorized() {
        activeUser.setIsActive(false);
        LoginRequest req = new LoginRequest();
        req.setUsername("testuser");
        req.setPassword("password");

        when(userRepository.findByUsername("testuser")).thenReturn(Optional.of(activeUser));

        assertThatThrownBy(() -> authService.login(req, "127.0.0.1"))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessageContaining("pasif");
    }
}
