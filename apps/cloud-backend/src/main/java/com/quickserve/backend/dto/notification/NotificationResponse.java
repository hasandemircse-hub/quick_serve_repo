package com.quickserve.backend.dto.notification;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class NotificationResponse {
    private Long id;
    private String type;
    private String title;
    private String titleEn;
    private String message;
    private String messageEn;
    private Boolean isRead;
    private String data;
    private LocalDateTime createdAt;
}
