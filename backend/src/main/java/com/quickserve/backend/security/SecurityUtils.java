package com.quickserve.backend.security;

import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.exception.UnauthorizedException;
import com.quickserve.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class SecurityUtils {

    private final UserRepository userRepository;

    public User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || "anonymousUser".equals(auth.getPrincipal())) {
            throw new UnauthorizedException("Authentication required");
        }
        String username = auth.getName();
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new UnauthorizedException("User not found"));
    }

    public User getCurrentUserOrNull() {
        try {
            return getCurrentUser();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Mevcut kullanıcının verilen restaurantId'ye erişimi var mı kontrol eder.
     * SUPERADMIN her şeye erişebilir. Diğerleri sadece kendi restoranlarına.
     */
    public void assertRestaurantAccess(Long restaurantId) {
        User user = getCurrentUser();
        if (user.getRole() == UserRole.SUPERADMIN) return;
        if (user.getRestaurant() == null || !user.getRestaurant().getId().equals(restaurantId)) {
            throw new UnauthorizedException("Access denied to restaurant " + restaurantId);
        }
    }

    public void assertRole(UserRole... roles) {
        User user = getCurrentUser();
        for (UserRole role : roles) {
            if (user.getRole() == role) return;
        }
        throw new UnauthorizedException("Insufficient permissions");
    }

    public boolean hasRole(UserRole role) {
        try {
            User user = getCurrentUser();
            return user.getRole() == role;
        } catch (Exception e) {
            return false;
        }
    }

    public boolean isSuperadmin() {
        return hasRole(UserRole.SUPERADMIN);
    }

    /**
     * İmpersonation-aware restaurant ID çözümleyici.
     * Normal kullanıcılar için: user.getRestaurant().getId()
     * Impersonation token'ında: JWT'deki restaurantId claim'i
     */
    public Long getCurrentRestaurantId() {
        User user = getCurrentUser();
        if (user.getRestaurant() != null) {
            return user.getRestaurant().getId();
        }
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth.getDetails() instanceof JwtAuthDetails details && details.restaurantId() != null) {
            return details.restaurantId();
        }
        throw new UnauthorizedException("No restaurant context for current user");
    }
}
