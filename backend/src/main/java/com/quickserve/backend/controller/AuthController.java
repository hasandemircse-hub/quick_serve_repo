package com.quickserve.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.quickserve.backend.dto.auth.AuthResponse;
import com.quickserve.backend.dto.auth.LoginRequest;
import com.quickserve.backend.service.AuthService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Tag(name = "Auth", description = "Kullanıcı giriş işlemleri")
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    @Operation(summary = "Personel/Admin girişi (JWT döner)")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request,
                                               HttpServletRequest httpRequest) {
        String ip = httpRequest.getRemoteAddr();
        return ResponseEntity.ok(authService.login(request, ip));
    }

    @GetMapping("/test-users")
    @Operation(summary = "Test için mevcut kullanıcıları listele")
    public ResponseEntity<String> getTestUsers() {
        return ResponseEntity.ok("Test kullanıcıları: s / 1");
    }
}
