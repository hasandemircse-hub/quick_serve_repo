package com.quickserve.backend.dto.payment;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class PayableItemResponse {
    private Long orderId;
    private Long orderItemId;
    private String orderStatus;
    private String menuItemName;
    private Integer quantity;
    private BigDecimal unitPrice;
    private BigDecimal lineTotal;
    private BigDecimal paidAmount;
    private BigDecimal outstandingAmount;
}
