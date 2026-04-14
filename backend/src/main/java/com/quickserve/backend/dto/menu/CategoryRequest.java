package com.quickserve.backend.dto.menu;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class CategoryRequest {
    @NotBlank
    private String name;
    private String nameEn;
    private Integer displayOrder;
    private Boolean isActive;
}
