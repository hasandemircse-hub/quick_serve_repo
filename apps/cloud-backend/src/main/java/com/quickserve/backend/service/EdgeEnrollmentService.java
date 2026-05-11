package com.quickserve.backend.service;

import com.quickserve.backend.dto.edge.*;
import com.quickserve.backend.entity.EdgeEnrollmentToken;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.EdgeEnrollmentTokenRepository;
import com.quickserve.backend.repository.UserRepository;
import com.quickserve.backend.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class EdgeEnrollmentService {

    private static final int DEFAULT_TTL_MINUTES = 30;
    private static final String TOKEN_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

    private final EdgeEnrollmentTokenRepository tokenRepository;
    private final RestaurantService restaurantService;
    private final EdgeNodeService edgeNodeService;
    private final AuditService auditService;
    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public EdgeEnrollmentTokenResponse createToken(Long restaurantId, Integer ttlMinutes) {
        Restaurant restaurant = restaurantService.findById(restaurantId);
        int ttl = (ttlMinutes == null || ttlMinutes < 1) ? DEFAULT_TTL_MINUTES : ttlMinutes;

        EdgeEnrollmentToken token = EdgeEnrollmentToken.builder()
                .restaurant(restaurant)
                .token(generateToken(32))
                .expiresAt(LocalDateTime.now().plusMinutes(ttl))
                .build();
        return toDto(tokenRepository.save(token));
    }

    @Transactional(readOnly = true)
    public List<EdgeEnrollmentTokenResponse> getTokens(Long restaurantId) {
        restaurantService.findById(restaurantId);
        return tokenRepository.findByRestaurantIdOrderByCreatedAtDesc(restaurantId)
                .stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public EdgeEnrollmentTokenResponse cancelToken(Long restaurantId, Long tokenId) {
        restaurantService.findById(restaurantId);
        EdgeEnrollmentToken token = tokenRepository.findByIdAndRestaurantId(tokenId, restaurantId)
                .orElseThrow(() -> new ResourceNotFoundException("EdgeEnrollmentToken", tokenId));

        if (!Boolean.TRUE.equals(token.getIsUsed())) {
            token.setIsUsed(true);
            token.setUsedAt(LocalDateTime.now());
            tokenRepository.save(token);
        }
        return toDto(token);
    }

    @Transactional
    public EdgeEnrollmentClaimResponse claimToken(EdgeEnrollmentClaimRequest request) {
        EdgeEnrollmentToken enrollmentToken = tokenRepository.findByToken(request.getToken())
                .orElseThrow(() -> new ResourceNotFoundException("EdgeEnrollmentToken not found"));

        if (Boolean.TRUE.equals(enrollmentToken.getIsUsed())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enrollment token already used");
        }
        if (enrollmentToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enrollment token expired");
        }

        EdgeNodeResponse edgeNode = edgeNodeService.createByEnrollment(
                enrollmentToken.getRestaurant().getId(),
                request.getNodeName(),
                request.getDeviceType(),
                request.getLocalIp()
        );

        enrollmentToken.setIsUsed(true);
        enrollmentToken.setUsedAt(LocalDateTime.now());
        tokenRepository.save(enrollmentToken);

        auditService.logSecurityEvent(
                "EDGE:" + request.getNodeName(),
                "EDGE_ENROLLMENT_CLAIM",
                "restaurantId=" + enrollmentToken.getRestaurant().getId() + ", edgeNodeId=" + edgeNode.getId(),
                request.getLocalIp()
        );

        User bridgePrincipal = resolveBridgePrincipal(enrollmentToken.getRestaurant().getId());
        String bridgeJwtToken = jwtUtil.generateToken(bridgePrincipal);

        return EdgeEnrollmentClaimResponse.builder()
                .restaurantId(enrollmentToken.getRestaurant().getId())
                .edgeNode(edgeNode)
                .bridgeJwtToken(bridgeJwtToken)
                .build();
    }

    @Transactional
    public int cleanupExpiredTokens() {
        List<EdgeEnrollmentToken> expiredTokens = tokenRepository.findByExpiresAtBefore(LocalDateTime.now());
        if (expiredTokens.isEmpty()) return 0;
        tokenRepository.deleteAll(expiredTokens);
        return expiredTokens.size();
    }

    private String generateToken(int length) {
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            int idx = secureRandom.nextInt(TOKEN_CHARS.length());
            sb.append(TOKEN_CHARS.charAt(idx));
        }
        return sb.toString();
    }

    /**
     * Edge cloud bridge için kullanıcı-bağımsız servis token:
     * 1) Restoran admin (aktif) varsa onu kullan
     * 2) Yoksa aktif waiter/head waiter/chef/valet
     * 3) Son çare: superadmin
     */
    private User resolveBridgePrincipal(Long restaurantId) {
        List<User> admins = userRepository.findByRestaurantIdAndRoleAndIsActiveTrue(restaurantId, UserRole.RESTAURANT_ADMIN);
        if (!admins.isEmpty()) {
            return admins.getFirst();
        }
        for (UserRole role : List.of(UserRole.HEAD_WAITER, UserRole.WAITER, UserRole.CHEF, UserRole.VALET)) {
            List<User> staff = userRepository.findByRestaurantIdAndRoleAndIsActiveTrue(restaurantId, role);
            if (!staff.isEmpty()) {
                return staff.getFirst();
            }
        }
        return userRepository.findAllSuperadmins().stream()
                .filter(u -> Boolean.TRUE.equals(u.getIsActive()))
                .findFirst()
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.BAD_REQUEST,
                        "No active principal found for edge bridge token"));
    }

    private EdgeEnrollmentTokenResponse toDto(EdgeEnrollmentToken token) {
        return EdgeEnrollmentTokenResponse.builder()
                .id(token.getId())
                .restaurantId(token.getRestaurant().getId())
                .token(token.getToken())
                .isUsed(token.getIsUsed())
                .expiresAt(token.getExpiresAt())
                .usedAt(token.getUsedAt())
                .createdAt(token.getCreatedAt())
                .build();
    }
}
