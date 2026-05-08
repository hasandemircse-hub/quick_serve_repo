package com.quickserve.backend.dto.menu;

import lombok.Data;

@Data
public class ReorderRequest {
    private Long id;
    private Integer displayOrder;
}
