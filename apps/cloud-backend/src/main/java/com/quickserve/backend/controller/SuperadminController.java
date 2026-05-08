package com.quickserve.backend.controller;

import com.quickserve.backend.dto.auth.AuthResponse;
import com.quickserve.backend.dto.report.MultiRestaurantOpsReportResponse;
import com.quickserve.backend.dto.restaurant.RestaurantRequest;
import com.quickserve.backend.dto.restaurant.RestaurantResponse;
import com.quickserve.backend.dto.user.UserRequest;
import com.quickserve.backend.dto.user.UserResponse;
import com.quickserve.backend.entity.AuditLog;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.SubscriptionStatus;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.security.JwtUtil;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/superadmin")
@RequiredArgsConstructor
@Tag(name = "Superadmin", description = "Superadmin - tüm restoranları yönetir")
public class SuperadminController {

    private final RestaurantService restaurantService;
    private final StaffService staffService;
    private final SubscriptionService subscriptionService;
    private final SmsService smsService;
    private final SecurityUtils securityUtils;
    private final JwtUtil jwtUtil;
    private final AuditService auditService;
    private final OpsReportService opsReportService;

    // ──── Restoran Yönetimi ──────────────────────────────────────────────────

    @GetMapping("/restaurants")
    public ResponseEntity<List<RestaurantResponse>> getAllRestaurants() {
        return ResponseEntity.ok(restaurantService.getAll());
    }

    @GetMapping("/reports/operations")
    public ResponseEntity<MultiRestaurantOpsReportResponse> getOperationsReport(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "OPS_REPORT_VIEW",
                "REPORT", null,
                "from=" + from + ", to=" + to,
                null, null
        );
        return ResponseEntity.ok(opsReportService.getMultiRestaurantOpsReport(from, to));
    }

    @GetMapping("/audit-logs")
    public ResponseEntity<Page<AuditLog>> getAuditLogs(
            @RequestParam(required = false) Long restaurantId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(auditService.getAuditLogs(restaurantId, page, size));
    }

    @GetMapping("/restaurants/{id}")
    public ResponseEntity<RestaurantResponse> getRestaurant(@PathVariable Long id) {
        return ResponseEntity.ok(restaurantService.getById(id));
    }

    @PostMapping("/restaurants")
    public ResponseEntity<RestaurantResponse> createRestaurant(@Valid @RequestBody RestaurantRequest request) {
        RestaurantResponse response = restaurantService.create(request);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "RESTAURANT_CREATE",
                "RESTAURANT", response.getId(),
                "name=" + response.getName(),
                null, response.getId()
        );
        return ResponseEntity.ok(response);
    }

    @PutMapping("/restaurants/{id}")
    public ResponseEntity<RestaurantResponse> updateRestaurant(@PathVariable Long id,
                                                                @Valid @RequestBody RestaurantRequest request) {
        RestaurantResponse response = restaurantService.update(id, request);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "RESTAURANT_UPDATE",
                "RESTAURANT", id,
                "name=" + response.getName(),
                null, id
        );
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/restaurants/{id}")
    public ResponseEntity<Void> deleteRestaurant(@PathVariable Long id) {
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "RESTAURANT_DELETE",
                "RESTAURANT", id,
                null, null, id
        );
        restaurantService.delete(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/restaurants/{id}/active")
    public ResponseEntity<Void> setActive(@PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        restaurantService.setActive(id, body.get("active"));
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "RESTAURANT_SET_ACTIVE",
                "RESTAURANT", id,
                "active=" + body.get("active"),
                null, id
        );
        return ResponseEntity.ok().build();
    }

    @PostMapping("/restaurants/{id}/subscription")
    public ResponseEntity<Void> updateSubscription(
            @PathVariable Long id,
            @RequestParam SubscriptionStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime expiresAt,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime demoExpiresAt) {
        restaurantService.setSubscriptionStatus(id, status, expiresAt, demoExpiresAt);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "RESTAURANT_SUBSCRIPTION_UPDATE",
                "RESTAURANT", id,
                "status=" + status + ", expiresAt=" + expiresAt + ", demoExpiresAt=" + demoExpiresAt,
                null, id
        );
        return ResponseEntity.ok().build();
    }

    // ──── Impersonate (Superadmin → Admin paneline giriş) ────────────────────

    @PostMapping("/restaurants/{id}/impersonate")
    public ResponseEntity<AuthResponse> impersonate(@PathVariable Long id) {
        User superadmin = securityUtils.getCurrentUser();
        String token = jwtUtil.generateImpersonationToken(
                superadmin, id, UserRole.RESTAURANT_ADMIN.name());
        RestaurantResponse restaurant = restaurantService.getById(id);
        auditService.logUserAction(
                superadmin.getId(), superadmin.getUsername(), "RESTAURANT_IMPERSONATE",
                "RESTAURANT", id,
                "targetRole=" + UserRole.RESTAURANT_ADMIN.name(),
                null, id
        );
        return ResponseEntity.ok(AuthResponse.builder()
                .token(token)
                .username(superadmin.getUsername())
                .fullName(superadmin.getFullName())
                .role(UserRole.RESTAURANT_ADMIN)
                .restaurantId(id)
                .restaurantName(restaurant.getName())
                .userId(superadmin.getId())
                .isMenuImagesEnabled(restaurant.getIsMenuImagesEnabled())
                .isPosDeviceEnabled(restaurant.getIsPosDeviceEnabled())
                .build());
    }

    // ──── Abonelik Yönetimi ──────────────────────────────────────────────────

    @PostMapping("/restaurants/{id}/subscriptions")
    public ResponseEntity<Void> createSubscription(@PathVariable Long id,
                                                    @RequestBody Map<String, String> body) {
        BigDecimal amount = new BigDecimal(body.get("amount"));
        LocalDate dueDate = LocalDate.parse(body.get("dueDate"));
        LocalDate periodStart = body.containsKey("periodStart") ? LocalDate.parse(body.get("periodStart")) : null;
        LocalDate periodEnd = body.containsKey("periodEnd") ? LocalDate.parse(body.get("periodEnd")) : null;
        subscriptionService.createSubscription(id, amount, dueDate, periodStart, periodEnd);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "SUBSCRIPTION_CREATE",
                "SUBSCRIPTION", null,
                "restaurantId=" + id + ", amount=" + amount + ", dueDate=" + dueDate,
                null, id
        );
        return ResponseEntity.ok().build();
    }

    @PostMapping("/subscriptions/{id}/paid")
    public ResponseEntity<Void> markPaid(@PathVariable Long id, @RequestBody Map<String, String> body) {
        subscriptionService.markPaid(id, body.get("reference"));
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "SUBSCRIPTION_MARK_PAID",
                "SUBSCRIPTION", id,
                "reference=" + body.get("reference"),
                null, null
        );
        return ResponseEntity.ok().build();
    }

    @GetMapping("/restaurants/{id}/subscriptions")
    public ResponseEntity<List<?>> getSubscriptions(@PathVariable Long id) {
        return ResponseEntity.ok(subscriptionService.getRestaurantSubscriptions(id));
    }

    // ──── Personel Yönetimi (Superadmin herhangi bir restoran için) ─────────

    @GetMapping("/restaurants/{id}/staff")
    public ResponseEntity<List<UserResponse>> getStaff(@PathVariable Long id) {
        return ResponseEntity.ok(staffService.getStaff(id));
    }

    @PostMapping("/restaurants/{id}/staff")
    public ResponseEntity<UserResponse> createStaff(@PathVariable Long id,
                                                     @Valid @RequestBody UserRequest request) {
        UserResponse response = staffService.createStaff(id, request);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "STAFF_CREATE",
                "USER", response.getId(),
                "role=" + response.getRole() + ", username=" + response.getUsername(),
                null, id
        );
        return ResponseEntity.ok(response);
    }

    @PutMapping("/restaurants/{restaurantId}/staff/{userId}")
    public ResponseEntity<UserResponse> updateStaff(@PathVariable Long restaurantId,
                                                     @PathVariable Long userId,
                                                     @RequestBody UserRequest request) {
        UserResponse response = staffService.updateStaff(userId, request);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "STAFF_UPDATE",
                "USER", userId,
                "role=" + response.getRole() + ", username=" + response.getUsername(),
                null, restaurantId
        );
        return ResponseEntity.ok(response);
    }

    @PostMapping("/restaurants/{restaurantId}/staff/{userId}/active")
    public ResponseEntity<Void> setStaffActive(@PathVariable Long restaurantId,
                                                @PathVariable Long userId,
                                                @RequestBody Map<String, Boolean> body) {
        staffService.setActive(userId, body.get("active"));
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "STAFF_SET_ACTIVE",
                "USER", userId,
                "active=" + body.get("active"),
                null, restaurantId
        );
        return ResponseEntity.ok().build();
    }

    @PostMapping("/restaurants/{restaurantId}/staff/{userId}/leave")
    public ResponseEntity<Void> setStaffLeave(@PathVariable Long restaurantId,
                                               @PathVariable Long userId,
                                               @RequestBody Map<String, String> body) {
        boolean onLeave = Boolean.parseBoolean(body.get("onLeave"));
        staffService.setLeave(userId, onLeave, body.get("reason"));
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "STAFF_SET_LEAVE",
                "USER", userId,
                "onLeave=" + onLeave + ", reason=" + body.get("reason"),
                null, restaurantId
        );
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/restaurants/{restaurantId}/staff/{userId}")
    public ResponseEntity<Void> deleteStaff(@PathVariable Long restaurantId,
                                             @PathVariable Long userId) {
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(), actor.getUsername(), "STAFF_DELETE",
                "USER", userId,
                null, null, restaurantId
        );
        staffService.deleteStaff(userId);
        return ResponseEntity.noContent().build();
    }

    // ──── Superadmin kullanıcısı oluşturma ──────────────────────────────────

    @PostMapping("/staff")
    public ResponseEntity<UserResponse> createSuperadminUser(@Valid @RequestBody UserRequest request) {
        return ResponseEntity.ok(staffService.createStaff(null, request));
    }

    // ──── SMS ────────────────────────────────────────────────────────────────

    @PostMapping("/restaurants/{id}/sms")
    public ResponseEntity<Void> sendSms(@PathVariable Long id, @RequestBody Map<String, String> body) {
        RestaurantResponse r = restaurantService.getById(id);
        if (r.getPhone() != null) {
            smsService.sendSms(r.getPhone(), body.get("message"));
        }
        return ResponseEntity.ok().build();
    }
}
