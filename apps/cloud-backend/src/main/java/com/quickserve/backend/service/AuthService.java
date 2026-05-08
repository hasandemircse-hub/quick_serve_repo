package com.quickserve.backend.service;

import com.quickserve.backend.dto.auth.AuthResponse;
import com.quickserve.backend.dto.auth.LoginRequest;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.exception.UnauthorizedException;
import com.quickserve.backend.repository.UserRepository;
import com.quickserve.backend.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;
    private final AuditService auditService;

    @Transactional
    public AuthResponse login(LoginRequest request, String ipAddress) {
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
            );
        } catch (BadCredentialsException e) {
            auditService.logSecurityEvent(request.getUsername(), "LOGIN_FAILED",
                    "Invalid credentials", ipAddress);
            throw new UnauthorizedException("Kullanıcı adı veya şifre hatalı");
        }

        User user = userRepository.findByUsername(request.getUsername())
                .orElseThrow(() -> new UnauthorizedException("Kullanıcı bulunamadı"));

        if (!user.getIsActive()) {
            throw new UnauthorizedException("Hesabınız pasif durumda");
        }

        // Abonelik kontrolü (SUPERADMIN hariç)
        if (user.getRole() != UserRole.SUPERADMIN && user.getRestaurant() != null) {
            if (!user.getRestaurant().getIsActive()) {
                throw new UnauthorizedException("Restoran hesabı aktif değil");
            }
            if (!user.getRestaurant().isSubscriptionValid()) {
                throw new UnauthorizedException("Restoran abonelik süresi dolmuş");
            }
        }

        user.setLastLoginAt(LocalDateTime.now());
        userRepository.save(user);

        String token = jwtUtil.generateToken(user);

        auditService.logUserAction(user.getId(), user.getUsername(), "LOGIN",
                "User", user.getId(), null, ipAddress,
                user.getRestaurant() != null ? user.getRestaurant().getId() : null);

        var restaurant = user.getRestaurant();
        return AuthResponse.builder()
                .token(token)
                .username(user.getUsername())
                .fullName(user.getFullName())
                .role(user.getRole())
                .userId(user.getId())
                .restaurantId(restaurant != null ? restaurant.getId() : null)
                .restaurantName(restaurant != null ? restaurant.getName() : null)
                .isMenuImagesEnabled(restaurant != null ? restaurant.getIsMenuImagesEnabled() : null)
                .isPosDeviceEnabled(restaurant != null ? restaurant.getIsPosDeviceEnabled() : null)
                .build();
    }
}
