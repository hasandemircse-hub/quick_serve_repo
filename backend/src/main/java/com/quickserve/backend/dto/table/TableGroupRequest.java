package com.quickserve.backend.dto.table;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class TableGroupRequest {
    @NotBlank
    private String name;
    private Integer displayOrder;
}
