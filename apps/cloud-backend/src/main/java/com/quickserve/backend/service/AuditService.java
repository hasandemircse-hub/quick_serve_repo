package com.quickserve.backend.service;

import com.quickserve.backend.entity.AuditLog;
import com.quickserve.backend.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuditService {

    private final AuditLogRepository auditLogRepository;

    @Async
    public void logUserAction(Long userId, String username, String action,
                               String entityType, Long entityId, String details,
                               String ipAddress, Long restaurantId) {
        try {
            AuditLog log = AuditLog.builder()
                    .actorType("USER")
                    .actorId(userId)
                    .actorName(username)
                    .action(action)
                    .entityType(entityType)
                    .entityId(entityId)
                    .details(details)
                    .ipAddress(ipAddress)
                    .restaurantId(restaurantId)
                    .build();
            auditLogRepository.save(log);
        } catch (Exception e) {
            log.error("Audit log failed for action {}: {}", action, e.getMessage());
        }
    }

    @Async
    public void logCustomerAction(String sessionToken, String action,
                                   String entityType, Long entityId, String details,
                                   String ipAddress, Long restaurantId) {
        try {
            AuditLog log = AuditLog.builder()
                    .actorType("CUSTOMER")
                    .actorName("session:" + sessionToken)
                    .action(action)
                    .entityType(entityType)
                    .entityId(entityId)
                    .details(details)
                    .ipAddress(ipAddress)
                    .restaurantId(restaurantId)
                    .build();
            auditLogRepository.save(log);
        } catch (Exception e) {
            log.error("Audit log failed for customer action {}: {}", action, e.getMessage());
        }
    }

    @Async
    public void logSecurityEvent(String actorInfo, String action, String details, String ipAddress) {
        try {
            AuditLog log = AuditLog.builder()
                    .actorType("SECURITY")
                    .actorName(actorInfo)
                    .action(action)
                    .details(details)
                    .ipAddress(ipAddress)
                    .build();
            auditLogRepository.save(log);
        } catch (Exception e) {
            this.log.error("Security audit log failed: {}", e.getMessage());
        }
    }

    public Page<AuditLog> getAuditLogs(Long restaurantId, int page, int size) {
        PageRequest pageable = PageRequest.of(page, size);
        if (restaurantId != null) {
            return auditLogRepository.findByRestaurantIdOrderByCreatedAtDesc(restaurantId, pageable);
        }
        return auditLogRepository.findAllByOrderByCreatedAtDesc(pageable);
    }
}
