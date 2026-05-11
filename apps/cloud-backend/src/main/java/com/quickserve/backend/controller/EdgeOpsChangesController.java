package com.quickserve.backend.controller;

import com.quickserve.backend.config.EdgeCloudLabBridge;
import com.quickserve.backend.dto.edge.EdgeOpsChangesResponse;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.exception.UnauthorizedException;
import com.quickserve.backend.repository.RestaurantRepository;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.EdgeOpsChangesService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/edge/ops")
@RequiredArgsConstructor
@Tag(name = "Edge ops", description = "Cloud uygulanmış edge olayları (cursor ile çekme)")
public class EdgeOpsChangesController {

    private final EdgeOpsChangesService edgeOpsChangesService;
    private final SecurityUtils securityUtils;
    private final EdgeCloudLabBridge edgeCloudLabBridge;
    private final RestaurantRepository restaurantRepository;

    @GetMapping("/changes")
    @Operation(summary = "Uygulanmış edge senkron olayları (since id üzerinden)")
    public ResponseEntity<EdgeOpsChangesResponse> changes(
            @RequestParam Long restaurantId,
            @RequestParam(name = "since", required = false) Long sinceId,
            @RequestParam(name = "limit", defaultValue = "100") int limit
    ) {
        assertRestaurantAccess(restaurantId);
        return ResponseEntity.ok(edgeOpsChangesService.listAppliedChanges(restaurantId, sinceId, limit));
    }

    private void assertRestaurantAccess(Long restaurantId) {
        User user = securityUtils.getCurrentUserOrNull();
        if (user != null) {
            securityUtils.assertRestaurantAccess(restaurantId);
            return;
        }
        if (edgeCloudLabBridge.enabled() && restaurantId != null && restaurantId > 0) {
            if (!restaurantRepository.existsById(restaurantId)) {
                throw new UnauthorizedException("Invalid restaurantId");
            }
            return;
        }
        throw new UnauthorizedException("Authentication required");
    }
}
