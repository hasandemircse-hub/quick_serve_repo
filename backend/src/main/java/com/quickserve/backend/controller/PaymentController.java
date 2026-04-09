package com.quickserve.backend.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.quickserve.backend.model.Payment;
import com.quickserve.backend.model.PaymentStatus;
import com.quickserve.backend.service.PaymentService;

@RestController
@RequestMapping("/api/payments")
@CrossOrigin(origins = "*")
public class PaymentController {
    @Autowired
    private PaymentService paymentService;

    @GetMapping
    public ResponseEntity<List<Payment>> getAllPayments() {
        return ResponseEntity.ok(paymentService.getAllPayments());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Payment> getPaymentById(@PathVariable Long id) {
        return paymentService.getPaymentById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Payment> createPayment(@RequestBody Payment payment) {
        return ResponseEntity.ok(paymentService.createPayment(payment));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Payment> updatePayment(@PathVariable Long id, @RequestBody Payment paymentDetails) {
        return ResponseEntity.ok(paymentService.updatePayment(id, paymentDetails));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePayment(@PathVariable Long id) {
        paymentService.deletePayment(id);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/status/{status}")
    public ResponseEntity<List<Payment>> getPaymentsByStatus(@PathVariable PaymentStatus status) {
        return ResponseEntity.ok(paymentService.getPaymentsByStatus(status));
    }

    @GetMapping("/pending")
    public ResponseEntity<List<Payment>> getPendingPayments() {
        return ResponseEntity.ok(paymentService.getPendingPayments());
    }

    @GetMapping("/completed")
    public ResponseEntity<List<Payment>> getCompletedPayments() {
        return ResponseEntity.ok(paymentService.getCompletedPayments());
    }

    @PostMapping("/{id}/complete")
    public ResponseEntity<Void> completePayment(@PathVariable Long id) {
        paymentService.completePayment(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/refund")
    public ResponseEntity<Void> refundPayment(@PathVariable Long id) {
        paymentService.refundPayment(id);
        return ResponseEntity.ok().build();
    }
}
