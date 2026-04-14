package com.quickserve.backend.entity;

import com.quickserve.backend.enums.TableStatus;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "restaurant_tables",
        uniqueConstraints = @UniqueConstraint(columnNames = {"restaurant_id", "table_number"}))
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RestaurantTable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "restaurant_id", nullable = false)
    private Restaurant restaurant;

    @NotBlank
    @Column(name = "table_number", nullable = false, length = 20)
    private String tableNumber;

    @Column(name = "qr_token", unique = true, length = 100)
    private String qrToken;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private TableStatus status = TableStatus.EMPTY;

    // Sürükle-bırak masa düzeni için koordinatlar
    @Column(name = "position_x")
    @Builder.Default
    private Integer positionX = 0;

    @Column(name = "position_y")
    @Builder.Default
    private Integer positionY = 0;

    @Column(name = "capacity")
    @Builder.Default
    private Integer capacity = 4;

    // İç/dış alan, teras vb.
    @Column(name = "zone", length = 50)
    private String zone;

    // Uzun süre bekleyen masa için son uyarı zamanı
    @Column(name = "last_alert_at")
    private LocalDateTime lastAlertAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
