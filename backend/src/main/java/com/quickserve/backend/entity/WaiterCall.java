package com.quickserve.backend.entity;

import com.quickserve.backend.enums.WaiterCallStatus;
import com.quickserve.backend.enums.WaiterCallType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "waiter_calls")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WaiterCall {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "table_session_id", nullable = false)
    private TableSession tableSession;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "restaurant_id", nullable = false)
    private Restaurant restaurant;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WaiterCallType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private WaiterCallStatus status = WaiterCallStatus.PENDING;

    // Çağrıyı üzerine alan garson
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_to_user_id")
    private User assignedTo;

    @Column(name = "notes", length = 300)
    private String notes;

    @CreationTimestamp
    @Column(name = "called_at", updatable = false)
    private LocalDateTime calledAt;

    @Column(name = "assigned_at")
    private LocalDateTime assignedAt;

    @Column(name = "resolved_at")
    private LocalDateTime resolvedAt;
}
