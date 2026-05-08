package com.quickserve.backend.dto.order;

import com.quickserve.backend.enums.OrderStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class OrderResponse {
    private Long id;
    private Long tableSessionId;
    private Long tableId;
    private String tableNumber;
    private OrderStatus status;
    private BigDecimal totalAmount;
    private List<OrderItemResponse> items;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime readyAt;
    private LocalDateTime deliveredAt;
    private Integer estimatedMinutes;
}
