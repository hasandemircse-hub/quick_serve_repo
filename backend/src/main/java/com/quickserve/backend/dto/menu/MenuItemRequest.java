package com.quickserve.backend.dto.menu;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
public class MenuItemRequest {
    @NotBlank
    private String name;
    private String nameEn;
    private String description;
    private String descriptionEn;
    @NotNull @DecimalMin("0.0")
    private BigDecimal price;
    private Long categoryId;
    private String imageUrl;
    private Boolean isActive;
    private Boolean isCampaign;
    private BigDecimal campaignPrice;
    private String campaignTitle;
    private String campaignImageUrl;
    private Integer preparationTimeMinutes;
    private Integer displayOrder;
    private List<NoteOptionRequest> noteOptions;
}
