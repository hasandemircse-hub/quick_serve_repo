package com.quickserve.backend.dto.order;

import com.quickserve.backend.enums.OrderStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class OrderItemResponse {
    private Long id;
    private Long menuItemId;
    private String menuItemName;
    private String menuItemNameEn;
    private String menuItemImageUrl;
    private Integer quantity;
    private BigDecimal unitPrice;
    private String note;
    private List<String> selectedNoteOptions;
    private OrderStatus status;
    private Integer sortOrder;
}
