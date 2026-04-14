package com.quickserve.backend.dto.table;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class TableRequest {
    @NotBlank
    private String tableNumber;
    private Integer capacity;
    private String zone;
    private Integer positionX;
    private Integer positionY;
}
