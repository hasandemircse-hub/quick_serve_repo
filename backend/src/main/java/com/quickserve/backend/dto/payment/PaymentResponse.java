package com.quickserve.backend.dto.payment;

import com.quickserve.backend.enums.PaymentMethod;
import com.quickserve.backend.enums.PaymentStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class PaymentResponse {
    private Long id;
    private PaymentMethod method;
    private BigDecimal amount;
    private BigDecimal tipAmount;
    private PaymentStatus status;
    private String failureReason;
    private LocalDateTime createdAt;
}
