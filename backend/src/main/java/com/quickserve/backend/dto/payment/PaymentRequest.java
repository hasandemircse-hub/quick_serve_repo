package com.quickserve.backend.dto.payment;

import com.quickserve.backend.enums.PaymentMethod;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
public class PaymentRequest {
    @NotNull
    private PaymentMethod method;
    @NotNull @DecimalMin("0.01")
    private BigDecimal amount;
    private BigDecimal tipAmount;
    private Long paymentSplitId;
    private List<PaymentAllocationRequest> allocations;
    // İyzico kart bilgileri (kart bilgileri doğrudan backend'e gelmez, token olarak gelir)
    private String iyzicoToken;  // Frontend'den İyzico checkout token'ı
    private String conversationId;
    private String note;
}
