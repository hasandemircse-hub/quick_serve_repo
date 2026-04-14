package com.quickserve.backend.entity;

import com.quickserve.backend.enums.CloseReason;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "table_sessions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TableSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "table_id", nullable = false)
    private RestaurantTable table;

    // QR okutunca müşteriye verilen oturum token (UUID)
    @Column(name = "session_token", unique = true, nullable = false, length = 100)
    private String sessionToken;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @CreationTimestamp
    @Column(name = "opened_at", updatable = false)
    private LocalDateTime openedAt;

    @Column(name = "closed_at")
    private LocalDateTime closedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "close_reason")
    private CloseReason closeReason;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "closed_by_user_id")
    private User closedBy;

    @Column(name = "guest_count")
    @Builder.Default
    private Integer guestCount = 1;

    // Masada bağlanan farklı telefon sayısı (aynı oturum)
    @Column(name = "device_count")
    @Builder.Default
    private Integer deviceCount = 1;

    public Long getRestaurantId() {
        return table != null && table.getRestaurant() != null
                ? table.getRestaurant().getId()
                : null;
    }
}
