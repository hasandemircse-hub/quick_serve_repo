package com.quickserve.backend.service;

import com.quickserve.backend.dto.notification.NotificationResponse;
import com.quickserve.backend.entity.Notification;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.repository.NotificationRepository;
import com.quickserve.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Kullanıcıya DB bildirimi oluştur + WebSocket ile push gönder.
     */
    @Transactional
    public void notifyUser(User recipient, Restaurant restaurant, String type,
                            String title, String titleEn, String message, String messageEn, String data) {
        Notification notification = Notification.builder()
                .recipient(recipient)
                .restaurant(restaurant)
                .type(type)
                .title(title)
                .titleEn(titleEn)
                .message(message)
                .messageEn(messageEn)
                .data(data)
                .build();
        notification = notificationRepository.save(notification);

        // WebSocket push
        try {
            NotificationResponse dto = toDto(notification);
            messagingTemplate.convertAndSendToUser(
                    recipient.getUsername(),
                    "/notifications",
                    dto
            );
        } catch (Exception e) {
            log.warn("WebSocket push failed for user {}: {}", recipient.getUsername(), e.getMessage());
        }
    }

    /**
     * Restoran kanalına WebSocket mesajı yayınla (masa/sipariş olayları).
     */
    public void publishToRestaurant(Long restaurantId, String topic, Object payload) {
        try {
            messagingTemplate.convertAndSend(
                    "/topic/restaurant/" + restaurantId + "/" + topic,
                    payload
            );
        } catch (Exception e) {
            log.warn("WebSocket publish failed for restaurant {} topic {}: {}", restaurantId, topic, e.getMessage());
        }
    }

    /**
     * Müşteri oturumuna WebSocket mesajı yayınla (sipariş durumu).
     */
    public void publishToSession(String sessionToken, String topic, Object payload) {
        try {
            messagingTemplate.convertAndSend(
                    "/topic/session/" + sessionToken + "/" + topic,
                    payload
            );
        } catch (Exception e) {
            log.warn("WebSocket publish failed for session {} topic {}: {}", sessionToken, topic, e.getMessage());
        }
    }

    /**
     * Tüm superadminleri bilgilendir.
     */
    @Transactional
    public void notifySuperadmins(String type, String title, String message, String data) {
        List<User> superadmins = userRepository.findAllSuperadmins();
        for (User sa : superadmins) {
            notifyUser(sa, null, type, title, title, message, message, data);
        }
    }

    /**
     * Garson çağrısını restorandaki garsonlara bildir.
     */
    public void notifyWaiters(Long restaurantId, Object payload) {
        publishToRestaurant(restaurantId, "calls", payload);
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> getUnread(Long userId) {
        return notificationRepository.findByRecipientIdAndIsReadFalseOrderByCreatedAtDesc(userId)
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> getAll(Long userId) {
        return notificationRepository.findByRecipientIdOrderByCreatedAtDesc(userId)
                .stream().map(this::toDto).toList();
    }

    @Transactional
    public void markAllRead(Long userId) {
        notificationRepository.markAllReadByUser(userId);
    }

    @Transactional
    public void markRead(Long notificationId, Long userId) {
        notificationRepository.findById(notificationId).ifPresent(n -> {
            if (n.getRecipient().getId().equals(userId)) {
                n.setIsRead(true);
                notificationRepository.save(n);
            }
        });
    }

    private NotificationResponse toDto(Notification n) {
        return NotificationResponse.builder()
                .id(n.getId())
                .type(n.getType())
                .title(n.getTitle())
                .titleEn(n.getTitleEn())
                .message(n.getMessage())
                .messageEn(n.getMessageEn())
                .isRead(n.getIsRead())
                .data(n.getData())
                .createdAt(n.getCreatedAt())
                .build();
    }
}
