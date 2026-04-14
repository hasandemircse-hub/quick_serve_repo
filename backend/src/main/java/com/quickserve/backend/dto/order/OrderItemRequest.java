package com.quickserve.backend.dto.order;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class OrderItemRequest {
    @NotNull
    private Long menuItemId;
    @Min(1)
    private Integer quantity;
    private String note;
    private List<String> selectedNoteOptions;
}
