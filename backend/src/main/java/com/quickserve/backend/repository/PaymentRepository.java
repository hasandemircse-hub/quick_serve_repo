package com.quickserve.backend.repository;

import com.quickserve.backend.entity.Payment;
import com.quickserve.backend.enums.PaymentMethod;
import com.quickserve.backend.enums.PaymentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public interface PaymentRepository extends JpaRepository<Payment, Long> {

    List<Payment> findByTableSessionId(Long sessionId);

    List<Payment> findByTableSessionIdAndStatus(Long sessionId, PaymentStatus status);

    List<Payment> findByRestaurantIdAndCreatedAtBetween(Long restaurantId,
                                                         LocalDateTime from,
                                                         LocalDateTime to);

    // Garson performansı: bahşiş toplamı
    @Query("SELECT COALESCE(SUM(p.tipAmount), 0) FROM Payment p " +
           "WHERE p.waiter.id = :waiterId AND p.status = 'COMPLETED' " +
           "AND p.createdAt BETWEEN :from AND :to")
    BigDecimal sumTipsByWaiter(@Param("waiterId") Long waiterId,
                                @Param("from") LocalDateTime from,
                                @Param("to") LocalDateTime to);

    // Oturumda tüm ödemeler tamamlandı mı?
    @Query("SELECT CASE WHEN COUNT(p) = 0 THEN false ELSE true END FROM Payment p " +
           "WHERE p.tableSession.id = :sessionId AND p.status = 'COMPLETED'")
    boolean hasCompletedPayments(@Param("sessionId") Long sessionId);

    @Query("SELECT COALESCE(SUM(p.amount + p.tipAmount), 0) FROM Payment p " +
           "WHERE p.tableSession.id = :sessionId AND p.status = 'COMPLETED'")
    BigDecimal sumCompletedPaymentsForSession(@Param("sessionId") Long sessionId);

    @Modifying
    @Query("DELETE FROM Payment p WHERE p.restaurant.id = :restaurantId")
    void deleteByRestaurantId(@Param("restaurantId") Long restaurantId);
}
