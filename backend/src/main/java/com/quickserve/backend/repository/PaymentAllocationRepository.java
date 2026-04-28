package com.quickserve.backend.repository;

import com.quickserve.backend.entity.PaymentAllocation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;

public interface PaymentAllocationRepository extends JpaRepository<PaymentAllocation, Long> {
    List<PaymentAllocation> findByPaymentId(Long paymentId);
    List<PaymentAllocation> findByPaymentIdIn(Collection<Long> paymentIds);
}
