package com.quickserve.backend.service;

import com.quickserve.backend.dto.menu.*;
import com.quickserve.backend.entity.MenuCategory;
import com.quickserve.backend.entity.MenuItem;
import com.quickserve.backend.entity.MenuItemNoteOption;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.MenuCategoryRepository;
import com.quickserve.backend.repository.MenuItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MenuService {

    private final MenuItemRepository menuItemRepository;
    private final MenuCategoryRepository categoryRepository;
    private final RestaurantService restaurantService;

    // ──── Kategoriler ────────────────────────────────────────────────────────

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public MenuCategory createCategory(Long restaurantId, CategoryRequest request) {
        Restaurant restaurant = restaurantService.findById(restaurantId);
        MenuCategory category = MenuCategory.builder()
                .restaurant(restaurant)
                .name(request.getName())
                .nameEn(request.getNameEn())
                .displayOrder(request.getDisplayOrder() != null ? request.getDisplayOrder() : 0)
                .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                .build();
        return categoryRepository.save(category);
    }

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public MenuCategory updateCategory(Long restaurantId, Long categoryId, CategoryRequest request) {
        MenuCategory category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new ResourceNotFoundException("MenuCategory", categoryId));
        category.setName(request.getName());
        if (request.getNameEn() != null) category.setNameEn(request.getNameEn());
        if (request.getDisplayOrder() != null) category.setDisplayOrder(request.getDisplayOrder());
        if (request.getIsActive() != null) category.setIsActive(request.getIsActive());
        return categoryRepository.save(category);
    }

    @Transactional(readOnly = true)
    public List<MenuCategory> getCategories(Long restaurantId, boolean activeOnly) {
        return activeOnly
                ? categoryRepository.findByRestaurantIdAndIsActiveTrueOrderByDisplayOrder(restaurantId)
                : categoryRepository.findByRestaurantIdOrderByDisplayOrder(restaurantId);
    }

    // ──── Menü Ürünleri ──────────────────────────────────────────────────────

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public MenuItemResponse createItem(Long restaurantId, MenuItemRequest request) {
        Restaurant restaurant = restaurantService.findById(restaurantId);
        MenuCategory category = null;
        if (request.getCategoryId() != null) {
            category = categoryRepository.findById(request.getCategoryId())
                    .orElseThrow(() -> new ResourceNotFoundException("MenuCategory", request.getCategoryId()));
        }

        MenuItem item = MenuItem.builder()
                .restaurant(restaurant)
                .category(category)
                .name(request.getName())
                .nameEn(request.getNameEn())
                .description(request.getDescription())
                .descriptionEn(request.getDescriptionEn())
                .price(request.getPrice())
                .imageUrl(request.getImageUrl())
                .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                .isCampaign(request.getIsCampaign() != null ? request.getIsCampaign() : false)
                .campaignPrice(request.getCampaignPrice())
                .campaignTitle(request.getCampaignTitle())
                .campaignImageUrl(request.getCampaignImageUrl())
                .preparationTimeMinutes(request.getPreparationTimeMinutes() != null ? request.getPreparationTimeMinutes() : 15)
                .displayOrder(request.getDisplayOrder() != null ? request.getDisplayOrder() : 0)
                .noteOptions(new ArrayList<>())
                .build();

        if (request.getNoteOptions() != null) {
            for (NoteOptionRequest opt : request.getNoteOptions()) {
                item.getNoteOptions().add(MenuItemNoteOption.builder()
                        .menuItem(item).text(opt.getText()).textEn(opt.getTextEn()).build());
            }
        }
        return toDto(menuItemRepository.save(item));
    }

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public MenuItemResponse updateItem(Long restaurantId, Long itemId, MenuItemRequest request) {
        MenuItem item = menuItemRepository.findById(itemId)
                .orElseThrow(() -> new ResourceNotFoundException("MenuItem", itemId));

        if (request.getName() != null) item.setName(request.getName());
        if (request.getNameEn() != null) item.setNameEn(request.getNameEn());
        if (request.getDescription() != null) item.setDescription(request.getDescription());
        if (request.getPrice() != null) item.setPrice(request.getPrice());
        if (request.getImageUrl() != null) item.setImageUrl(request.getImageUrl());
        if (request.getIsActive() != null) item.setIsActive(request.getIsActive());
        if (request.getIsCampaign() != null) item.setIsCampaign(request.getIsCampaign());
        if (request.getCampaignPrice() != null) item.setCampaignPrice(request.getCampaignPrice());
        if (request.getCampaignTitle() != null) item.setCampaignTitle(request.getCampaignTitle());
        if (request.getPreparationTimeMinutes() != null) item.setPreparationTimeMinutes(request.getPreparationTimeMinutes());
        if (request.getDisplayOrder() != null) item.setDisplayOrder(request.getDisplayOrder());
        if (request.getCategoryId() != null) {
            MenuCategory category = categoryRepository.findById(request.getCategoryId())
                    .orElseThrow(() -> new ResourceNotFoundException("MenuCategory", request.getCategoryId()));
            item.setCategory(category);
        }
        if (request.getNoteOptions() != null) {
            item.getNoteOptions().clear();
            for (NoteOptionRequest opt : request.getNoteOptions()) {
                item.getNoteOptions().add(MenuItemNoteOption.builder()
                        .menuItem(item).text(opt.getText()).textEn(opt.getTextEn()).build());
            }
        }
        return toDto(menuItemRepository.save(item));
    }

    /**
     * Müşteri görünümü: sadece aktif, kaldırılmamış ürünler, kategorilere göre gruplu.
     */
    @Cacheable(value = "menus", key = "#restaurantId")
    @Transactional(readOnly = true)
    public Map<String, List<MenuItemResponse>> getMenuGrouped(Long restaurantId) {
        return menuItemRepository.findVisibleByRestaurantId(restaurantId).stream()
                .map(this::toDto)
                .collect(Collectors.groupingBy(item -> item.getCategoryName() != null ? item.getCategoryName() : "Diğer"));
    }

    @Transactional(readOnly = true)
    public List<MenuItemResponse> getAllItems(Long restaurantId) {
        return menuItemRepository.findByRestaurantIdOrderByCategoryDisplayOrderAscDisplayOrderAsc(restaurantId)
                .stream().map(this::toDto).toList();
    }

    /**
     * Mutfak: ürünü menüde kaldır veya "stokta yok" işaretle.
     */
    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public void setAvailability(Long restaurantId, Long itemId, boolean isAvailable, boolean removeFromMenu) {
        MenuItem item = menuItemRepository.findById(itemId)
                .orElseThrow(() -> new ResourceNotFoundException("MenuItem", itemId));
        item.setIsAvailable(isAvailable);
        item.setIsRemoved(removeFromMenu);
        menuItemRepository.save(item);
    }

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public void reorderCategories(Long restaurantId, List<ReorderRequest> items) {
        items.forEach(req -> {
            MenuCategory cat = categoryRepository.findById(req.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("MenuCategory", req.getId()));
            cat.setDisplayOrder(req.getDisplayOrder());
            categoryRepository.save(cat);
        });
    }

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public void reorderItems(Long restaurantId, List<ReorderRequest> items) {
        items.forEach(req -> {
            MenuItem item = menuItemRepository.findById(req.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("MenuItem", req.getId()));
            item.setDisplayOrder(req.getDisplayOrder());
            menuItemRepository.save(item);
        });
    }

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public void deleteCategory(Long restaurantId, Long categoryId) {
        MenuCategory category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new ResourceNotFoundException("MenuCategory", categoryId));
        if (menuItemRepository.existsByCategoryId(categoryId)) {
            throw new BusinessException("Bu kategoride ürün bulunduğu için silinemez. Önce ürünleri başka kategoriye taşıyın veya silin.");
        }
        categoryRepository.delete(category);
    }

    @Transactional
    @CacheEvict(value = "menus", key = "#restaurantId")
    public void deleteItem(Long restaurantId, Long itemId) {
        MenuItem item = menuItemRepository.findById(itemId)
                .orElseThrow(() -> new ResourceNotFoundException("MenuItem", itemId));
        menuItemRepository.delete(item);
    }

    public MenuItem findItemById(Long id) {
        return menuItemRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("MenuItem", id));
    }

    public MenuItemResponse toDto(MenuItem item) {
        return MenuItemResponse.builder()
                .id(item.getId())
                .name(item.getName())
                .nameEn(item.getNameEn())
                .description(item.getDescription())
                .descriptionEn(item.getDescriptionEn())
                .price(item.getPrice())
                .effectivePrice(item.getEffectivePrice())
                .categoryId(item.getCategory() != null ? item.getCategory().getId() : null)
                .categoryName(item.getCategory() != null ? item.getCategory().getName() : null)
                .categoryNameEn(item.getCategory() != null ? item.getCategory().getNameEn() : null)
                .imageUrl(item.getImageUrl())
                .isActive(item.getIsActive())
                .isAvailable(item.getIsAvailable())
                .isRemoved(item.getIsRemoved())
                .isCampaign(item.getIsCampaign())
                .campaignPrice(item.getCampaignPrice())
                .campaignTitle(item.getCampaignTitle())
                .campaignImageUrl(item.getCampaignImageUrl())
                .preparationTimeMinutes(item.getPreparationTimeMinutes())
                .displayOrder(item.getDisplayOrder())
                .noteOptions(item.getNoteOptions().stream()
                        .map(o -> NoteOptionResponse.builder()
                                .id(o.getId()).text(o.getText()).textEn(o.getTextEn()).build())
                        .toList())
                .build();
    }
}
