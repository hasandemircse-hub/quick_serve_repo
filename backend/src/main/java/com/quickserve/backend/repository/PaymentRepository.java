package com.quickserve.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.quickserve.backend.model.Order;
import com.quickserve.backend.model.Payment;
import com.quickserve.backend.model.PaymentStatus;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    List<Payment> findByOrder(Order order);
    List<Payment> findByStatus(PaymentStatus status);
    Optional<Payment> findByTransactionId(String transactionId);
}
