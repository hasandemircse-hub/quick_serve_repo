package com.quickserve.backend.security;

import com.quickserve.backend.entity.User;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Component
@Slf4j
public class JwtUtil {

    private static final String CLAIM_USER_ID       = "userId";
    private static final String CLAIM_ROLE          = "role";
    private static final String CLAIM_RESTAURANT_ID = "restaurantId";
    private static final String CLAIM_IMPERSONATED  = "impersonated";

    @Value("${app.jwt.secret}")
    private String secret;

    @Value("${app.jwt.expiration-ms}")
    private long expirationMs;

    /** HS256 için JJWT en az 32 bayt UTF-8 anahtar ister; kısa sırada login 500 döner. */
    @PostConstruct
    void validateJwtSecret() {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("app.jwt.secret / JWT_SECRET tanımlı olmalıdır.");
        }
        int len = secret.getBytes(StandardCharsets.UTF_8).length;
        if (len < 32) {
            throw new IllegalStateException(
                    "app.jwt.secret en az 32 UTF-8 bayt olmalı (şu an " + len + " bayt). Uzun bir JWT_SECRET kullanın.");
        }
    }

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generateToken(User user) {
        return Jwts.builder()
                .subject(user.getUsername())
                .claim(CLAIM_USER_ID, user.getId())
                .claim(CLAIM_ROLE, user.getRole().name())
                .claim(CLAIM_RESTAURANT_ID, user.getRestaurant() != null ? user.getRestaurant().getId() : null)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + expirationMs))
                .signWith(getSigningKey())
                .compact();
    }

    /** Superadmin'in belirli bir restoran adına kısa süreli token alması için. */
    public String generateImpersonationToken(User superadmin, Long restaurantId, String restaurantAdminRole) {
        return Jwts.builder()
                .subject(superadmin.getUsername())
                .claim(CLAIM_USER_ID, superadmin.getId())
                .claim(CLAIM_ROLE, restaurantAdminRole)
                .claim(CLAIM_RESTAURANT_ID, restaurantId)
                .claim(CLAIM_IMPERSONATED, true)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 3_600_000L)) // 1 saat
                .signWith(getSigningKey())
                .compact();
    }

    public Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public String extractUsername(String token) {
        return extractAllClaims(token).getSubject();
    }

    public Long extractUserId(String token) {
        return extractAllClaims(token).get(CLAIM_USER_ID, Long.class);
    }

    public String extractRole(String token) {
        return extractAllClaims(token).get(CLAIM_ROLE, String.class);
    }

    public Long extractRestaurantId(String token) {
        return extractAllClaims(token).get(CLAIM_RESTAURANT_ID, Long.class);
    }

    public boolean validateToken(String token) {
        try {
            extractAllClaims(token);
            return true;
        } catch (ExpiredJwtException e) {
            log.warn("JWT token expired: {}", e.getMessage());
        } catch (UnsupportedJwtException e) {
            log.warn("JWT token unsupported: {}", e.getMessage());
        } catch (MalformedJwtException e) {
            log.warn("JWT token malformed: {}", e.getMessage());
        } catch (SecurityException e) {
            log.warn("JWT signature invalid: {}", e.getMessage());
        } catch (IllegalArgumentException e) {
            log.warn("JWT token empty: {}", e.getMessage());
        }
        return false;
    }
}
