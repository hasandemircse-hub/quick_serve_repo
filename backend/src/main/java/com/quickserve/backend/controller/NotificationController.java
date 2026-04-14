package com.quickserve.backend.controller;

import com.quickserve.backend.dto.notification.NotificationResponse;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.NotificationService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/notifications")
@RequiredArgsConstructor
@Tag(name = "Notifications", description = "Bildirim yönetimi")
public class NotificationController {

    private final NotificationService notificationService;
    private final SecurityUtils securityUtils;

    @GetMapping
    public ResponseEntity<List<NotificationResponse>> getAll() {
        Long userId = securityUtils.getCurrentUser().getId();
        return ResponseEntity.ok(notificationService.getAll(userId));
    }

    @GetMapping("/unread")
    public ResponseEntity<List<NotificationResponse>> getUnread() {
        Long userId = securityUtils.getCurrentUser().getId();
        return ResponseEntity.ok(notificationService.getUnread(userId));
    }

    @PostMapping("/read-all")
    public ResponseEntity<Void> markAllRead() {
        Long userId = securityUtils.getCurrentUser().getId();
        notificationService.markAllRead(userId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long id) {
        Long userId = securityUtils.getCurrentUser().getId();
        notificationService.markRead(id, userId);
        return ResponseEntity.ok().build();
    }
}
