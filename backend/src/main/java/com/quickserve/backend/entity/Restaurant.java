package com.quickserve.backend.entity;

import com.quickserve.backend.enums.SubscriptionStatus;
import jakarta.persistence.*;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "restaurants")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Restaurant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank
    @Column(nullable = false, length = 150)
    private String name;

    @Column(length = 20)
    private String phone;

    @Email
    @Column(length = 150)
    private String email;

    @Column(length = 300)
    private String address;

    @Column(name = "logo_url", length = 500)
    private String logoUrl;

    @Column(name = "background_image_url", length = 500)
    private String backgroundImageUrl;

    @Column(name = "primary_color", length = 10)
    private String primaryColor;

    @Column(name = "font_family", length = 100)
    private String fontFamily;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Enumerated(EnumType.STRING)
    @Column(name = "subscription_status", nullable = false)
    @Builder.Default
    private SubscriptionStatus subscriptionStatus = SubscriptionStatus.DEMO;

    @Column(name = "subscription_expires_at")
    private LocalDateTime subscriptionExpiresAt;

    @Column(name = "demo_expires_at")
    private LocalDateTime demoExpiresAt;

    @Column(name = "iban_number", length = 50)
    private String ibanNumber;

    // İyzico sanal POS bilgileri (superadmin tarafından yönetilir)
    @Column(name = "iyzico_api_key", length = 200)
    private String iyzicoApiKey;

    @Column(name = "iyzico_secret_key", length = 200)
    private String iyzicoSecretKey;

    @Column(name = "iyzico_base_url", length = 200)
    @Builder.Default
    private String iyzicoBaseUrl = "https://sandbox-api.iyzipay.com";

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public boolean isSubscriptionValid() {
        return switch (subscriptionStatus) {
            case ACTIVE -> subscriptionExpiresAt == null || subscriptionExpiresAt.isAfter(LocalDateTime.now());
            case DEMO -> demoExpiresAt == null || demoExpiresAt.isAfter(LocalDateTime.now());
            default -> false;
        };
    }
}
