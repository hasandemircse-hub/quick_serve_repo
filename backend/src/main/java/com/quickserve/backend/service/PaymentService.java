package com.quickserve.backend.service;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.quickserve.backend.model.Order;
import com.quickserve.backend.model.Payment;
import com.quickserve.backend.model.PaymentStatus;
import com.quickserve.backend.repository.PaymentRepository;

@Service
public class PaymentService {
    @Autowired
    private PaymentRepository paymentRepository;

    public List<Payment> getAllPayments() {
        return paymentRepository.findAll();
    }

    public Optional<Payment> getPaymentById(Long id) {
        return paymentRepository.findById(id);
    }

    public Payment createPayment(Payment payment) {
        return paymentRepository.save(payment);
    }

    public Payment updatePayment(Long id, Payment paymentDetails) {
        return paymentRepository.findById(id).map(payment -> {
            payment.setAmount(paymentDetails.getAmount());
            payment.setMethod(paymentDetails.getMethod());
            payment.setStatus(paymentDetails.getStatus());
            payment.setTransactionId(paymentDetails.getTransactionId());
            return paymentRepository.save(payment);
        }).orElseThrow(() -> new RuntimeException("Ödeme bulunamadı"));
    }

    public void deletePayment(Long id) {
        paymentRepository.deleteById(id);
    }

    public List<Payment> getPaymentsByOrder(Order order) {
        return paymentRepository.findByOrder(order);
    }

    public List<Payment> getPaymentsByStatus(PaymentStatus status) {
        return paymentRepository.findByStatus(status);
    }

    public List<Payment> getPendingPayments() {
        return paymentRepository.findByStatus(PaymentStatus.PENDING);
    }

    public List<Payment> getCompletedPayments() {
        return paymentRepository.findByStatus(PaymentStatus.COMPLETED);
    }

    public void completePayment(Long paymentId) {
        paymentRepository.findById(paymentId).ifPresent(payment -> {
            payment.setStatus(PaymentStatus.COMPLETED);
            paymentRepository.save(payment);
        });
    }

    public void refundPayment(Long paymentId) {
        paymentRepository.findById(paymentId).ifPresent(payment -> {
            payment.setStatus(PaymentStatus.REFUNDED);
            paymentRepository.save(payment);
        });
    }
}
