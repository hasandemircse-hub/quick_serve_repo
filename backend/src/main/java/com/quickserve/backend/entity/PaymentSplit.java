package com.quickserve.backend.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Hesap bölme kaydı. Bir masa oturumunda birden fazla kişi farklı
 * yöntemlerle ödeme yapabilir (karma ödeme).
 *
 * TODO(TIP-ALLOCATION): Bahşiş bölme stratejisi netleştirilmeli.
 * Şu an bahşiş Payment entity'sinde tutulmaktadır.
 * Her split için ayrı bahşiş mi, yoksa toplam bahşiş mi?
 */
@Entity
@Table(name = "payment_splits")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentSplit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "table_session_id", nullable = false)
    private TableSession tableSession;

    // "Kişi 1", "Grup A" gibi etiket
    @Column(name = "split_label", length = 100)
    private String splitLabel;

    @Column(name = "amount", nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(name = "is_paid", nullable = false)
    @Builder.Default
    private Boolean isPaid = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
