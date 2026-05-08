package com.quickserve.backend.dto.menu;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class MenuItemResponse {
    private Long id;
    private String name;
    private String nameEn;
    private String description;
    private String descriptionEn;
    private BigDecimal price;
    private BigDecimal effectivePrice;
    private Long categoryId;
    private String categoryName;
    private String categoryNameEn;
    private String imageUrl;
    private Boolean showImage;
    private Boolean isActive;
    private Boolean isAvailable;
    private Boolean isRemoved;
    private Boolean isCampaign;
    private BigDecimal campaignPrice;
    private String campaignTitle;
    private String campaignImageUrl;
    private Integer preparationTimeMinutes;
    private Integer displayOrder;
    private List<NoteOptionResponse> noteOptions;
}
