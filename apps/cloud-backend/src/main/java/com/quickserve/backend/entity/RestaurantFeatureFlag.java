package com.quickserve.backend.entity;

import com.quickserve.backend.enums.FeatureCode;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "restaurant_feature_flags",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_restaurant_feature", columnNames = {"restaurant_id", "feature_code"})
        }
)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RestaurantFeatureFlag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "restaurant_id", nullable = false)
    private Restaurant restaurant;

    @Enumerated(EnumType.STRING)
    @Column(name = "feature_code", nullable = false, length = 50)
    private FeatureCode featureCode;

    @Column(nullable = false)
    @Builder.Default
    private Boolean enabled = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
