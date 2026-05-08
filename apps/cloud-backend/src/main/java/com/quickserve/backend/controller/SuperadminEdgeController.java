package com.quickserve.backend.controller;

import com.quickserve.backend.dto.edge.*;
import com.quickserve.backend.dto.feature.FeatureFlagRequest;
import com.quickserve.backend.dto.feature.FeatureFlagResponse;
import com.quickserve.backend.dto.feature.FeatureTemplateRequest;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.AuditService;
import com.quickserve.backend.service.EdgeEnrollmentService;
import com.quickserve.backend.service.EdgeNodeService;
import com.quickserve.backend.service.RestaurantFeatureFlagService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/superadmin")
@RequiredArgsConstructor
@Tag(name = "Superadmin Edge", description = "Superadmin edge node ve feature flag yönetimi")
public class SuperadminEdgeController {

    private final EdgeNodeService edgeNodeService;
    private final EdgeEnrollmentService edgeEnrollmentService;
    private final RestaurantFeatureFlagService featureFlagService;
    private final SecurityUtils securityUtils;
    private final AuditService auditService;

    @Operation(summary = "Restoran için tek kullanımlık edge enrollment token üret")
    @PostMapping("/restaurants/{restaurantId}/edge-enrollment-tokens")
    public ResponseEntity<EdgeEnrollmentTokenResponse> createEnrollmentToken(
            @Parameter(description = "Restoran ID", example = "1")
            @PathVariable Long restaurantId,
            @RequestBody(required = false) EdgeEnrollmentTokenRequest request) {
        Integer ttlMinutes = request == null ? null : request.getTtlMinutes();
        EdgeEnrollmentTokenResponse response = edgeEnrollmentService.createToken(restaurantId, ttlMinutes);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(),
                actor.getUsername(),
                "EDGE_ENROLLMENT_TOKEN_CREATE",
                "EDGE_ENROLLMENT_TOKEN",
                response.getId(),
                "restaurantId=" + restaurantId + ", ttlMinutes=" + ttlMinutes,
                null,
                restaurantId
        );
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Restoranın edge enrollment tokenlarını listele")
    @GetMapping("/restaurants/{restaurantId}/edge-enrollment-tokens")
    public ResponseEntity<List<EdgeEnrollmentTokenResponse>> getEnrollmentTokens(
            @Parameter(description = "Restoran ID", example = "1")
            @PathVariable Long restaurantId) {
        return ResponseEntity.ok(edgeEnrollmentService.getTokens(restaurantId));
    }

    @Operation(summary = "Restoranın edge enrollment tokenını iptal et")
    @PostMapping("/restaurants/{restaurantId}/edge-enrollment-tokens/{tokenId}/cancel")
    public ResponseEntity<EdgeEnrollmentTokenResponse> cancelEnrollmentToken(
            @PathVariable Long restaurantId,
            @PathVariable Long tokenId) {
        EdgeEnrollmentTokenResponse response = edgeEnrollmentService.cancelToken(restaurantId, tokenId);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(),
                actor.getUsername(),
                "EDGE_ENROLLMENT_TOKEN_CANCEL",
                "EDGE_ENROLLMENT_TOKEN",
                tokenId,
                "restaurantId=" + restaurantId,
                null,
                restaurantId
        );
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Süresi dolmuş edge enrollment tokenlarını temizle")
    @PostMapping("/edge-enrollment-tokens/cleanup")
    public ResponseEntity<EdgeEnrollmentCleanupResponse> cleanupExpiredEnrollmentTokens() {
        int deleted = edgeEnrollmentService.cleanupExpiredTokens();
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(),
                actor.getUsername(),
                "EDGE_ENROLLMENT_TOKEN_CLEANUP",
                "EDGE_ENROLLMENT_TOKEN",
                null,
                "deletedCount=" + deleted,
                null,
                null
        );
        return ResponseEntity.ok(EdgeEnrollmentCleanupResponse.builder().deletedCount(deleted).build());
    }

    @Operation(summary = "Restorana bağlı edge node listesini getir")
    @GetMapping("/restaurants/{restaurantId}/edge-nodes")
    public ResponseEntity<List<EdgeNodeResponse>> getEdgeNodes(
            @Parameter(description = "Restoran ID", example = "1")
            @PathVariable Long restaurantId) {
        return ResponseEntity.ok(edgeNodeService.getByRestaurantId(restaurantId));
    }

    @Operation(summary = "Edge node detayını getir")
    @GetMapping("/edge-nodes/{edgeNodeId}")
    public ResponseEntity<EdgeNodeResponse> getEdgeNode(
            @Parameter(description = "Edge node ID", example = "10")
            @PathVariable Long edgeNodeId) {
        return ResponseEntity.ok(edgeNodeService.getById(edgeNodeId));
    }

    @Operation(summary = "Restorana yeni edge node ekle")
    @PostMapping("/restaurants/{restaurantId}/edge-nodes")
    public ResponseEntity<EdgeNodeResponse> createEdgeNode(
            @Parameter(description = "Restoran ID", example = "1")
            @PathVariable Long restaurantId,
            @Valid @RequestBody EdgeNodeRequest request) {
        return ResponseEntity.ok(edgeNodeService.create(restaurantId, request));
    }

    @Operation(summary = "Edge node güncelle")
    @PutMapping("/edge-nodes/{edgeNodeId}")
    public ResponseEntity<EdgeNodeResponse> updateEdgeNode(
            @Parameter(description = "Edge node ID", example = "10")
            @PathVariable Long edgeNodeId,
            @Valid @RequestBody EdgeNodeRequest request) {
        return ResponseEntity.ok(edgeNodeService.update(edgeNodeId, request));
    }

    @Operation(summary = "Edge node sil")
    @DeleteMapping("/edge-nodes/{edgeNodeId}")
    public ResponseEntity<Void> deleteEdgeNode(
            @Parameter(description = "Edge node ID", example = "10")
            @PathVariable Long edgeNodeId) {
        edgeNodeService.delete(edgeNodeId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Restoran feature flag listesini getir")
    @GetMapping("/restaurants/{restaurantId}/feature-flags")
    public ResponseEntity<List<FeatureFlagResponse>> getFeatureFlags(
            @Parameter(description = "Restoran ID", example = "1")
            @PathVariable Long restaurantId) {
        return ResponseEntity.ok(featureFlagService.getByRestaurantId(restaurantId));
    }

    @Operation(summary = "Feature flag detayını getir")
    @GetMapping("/feature-flags/{flagId}")
    public ResponseEntity<FeatureFlagResponse> getFeatureFlag(
            @Parameter(description = "Feature flag ID", example = "20")
            @PathVariable Long flagId) {
        return ResponseEntity.ok(featureFlagService.getById(flagId));
    }

    @Operation(summary = "Restorana feature flag oluştur veya güncelle")
    @PostMapping("/restaurants/{restaurantId}/feature-flags")
    public ResponseEntity<FeatureFlagResponse> createFeatureFlag(
            @Parameter(description = "Restoran ID", example = "1")
            @PathVariable Long restaurantId,
            @Valid @RequestBody FeatureFlagRequest request) {
        FeatureFlagResponse response = featureFlagService.create(restaurantId, request);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(),
                actor.getUsername(),
                "FEATURE_FLAG_CREATE_OR_UPDATE",
                "FEATURE_FLAG",
                response.getId(),
                "restaurantId=" + restaurantId + ", featureCode=" + request.getFeatureCode() + ", enabled=" + request.getEnabled(),
                null,
                restaurantId
        );
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Feature flag kaydını güncelle")
    @PutMapping("/feature-flags/{flagId}")
    public ResponseEntity<FeatureFlagResponse> updateFeatureFlag(
            @Parameter(description = "Feature flag ID", example = "20")
            @PathVariable Long flagId,
            @Valid @RequestBody FeatureFlagRequest request) {
        FeatureFlagResponse response = featureFlagService.update(flagId, request);
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(),
                actor.getUsername(),
                "FEATURE_FLAG_UPDATE",
                "FEATURE_FLAG",
                flagId,
                "featureCode=" + request.getFeatureCode() + ", enabled=" + request.getEnabled(),
                null,
                response.getRestaurantId()
        );
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Restoran için feature template uygula (BASIC, PRO, ENTERPRISE)")
    @PostMapping("/restaurants/{restaurantId}/feature-flags/template")
    public ResponseEntity<List<FeatureFlagResponse>> applyFeatureTemplate(
            @Parameter(description = "Restoran ID", example = "1")
            @PathVariable Long restaurantId,
            @Valid @RequestBody FeatureTemplateRequest request) {
        List<FeatureFlagResponse> response = featureFlagService.applyTemplate(restaurantId, request.getTemplate());
        User actor = securityUtils.getCurrentUser();
        auditService.logUserAction(
                actor.getId(),
                actor.getUsername(),
                "FEATURE_TEMPLATE_APPLY",
                "FEATURE_TEMPLATE",
                null,
                "restaurantId=" + restaurantId + ", template=" + request.getTemplate(),
                null,
                restaurantId
        );
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Feature flag sil")
    @DeleteMapping("/feature-flags/{flagId}")
    public ResponseEntity<Void> deleteFeatureFlag(
            @Parameter(description = "Feature flag ID", example = "20")
            @PathVariable Long flagId) {
        User actor = securityUtils.getCurrentUser();
        FeatureFlagResponse current = featureFlagService.getById(flagId);
        auditService.logUserAction(
                actor.getId(),
                actor.getUsername(),
                "FEATURE_FLAG_DELETE",
                "FEATURE_FLAG",
                flagId,
                "featureCode=" + current.getFeatureCode(),
                null,
                current.getRestaurantId()
        );
        featureFlagService.delete(flagId);
        return ResponseEntity.noContent().build();
    }
}
