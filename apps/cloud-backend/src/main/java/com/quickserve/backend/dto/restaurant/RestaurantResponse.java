package com.quickserve.backend.dto.restaurant;

import com.quickserve.backend.enums.SubscriptionStatus;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class RestaurantResponse {
    private Long id;
    private String name;
    private String phone;
    private String email;
    private String address;
    private String logoUrl;
    private String backgroundImageUrl;
    private String primaryColor;
    private String fontFamily;
    private Boolean isMenuImagesEnabled;
    private Boolean isPosDeviceEnabled;
    private Boolean isActive;
    private SubscriptionStatus subscriptionStatus;
    private LocalDateTime subscriptionExpiresAt;
    private LocalDateTime demoExpiresAt;
    private Boolean subscriptionValid;
    private LocalDateTime createdAt;
    private int staffCount;
}
