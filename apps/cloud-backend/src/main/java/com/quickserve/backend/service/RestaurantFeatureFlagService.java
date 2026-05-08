package com.quickserve.backend.service;

import com.quickserve.backend.dto.feature.FeatureFlagRequest;
import com.quickserve.backend.dto.feature.FeatureFlagResponse;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.entity.RestaurantFeatureFlag;
import com.quickserve.backend.enums.FeatureCode;
import com.quickserve.backend.enums.FeatureTemplate;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.RestaurantFeatureFlagRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class RestaurantFeatureFlagService {

    private final RestaurantFeatureFlagRepository featureFlagRepository;
    private final RestaurantService restaurantService;

    @Transactional
    public FeatureFlagResponse create(Long restaurantId, FeatureFlagRequest request) {
        Restaurant restaurant = restaurantService.findById(restaurantId);

        RestaurantFeatureFlag flag = featureFlagRepository
                .findByRestaurantIdAndFeatureCode(restaurantId, request.getFeatureCode())
                .orElse(RestaurantFeatureFlag.builder()
                        .restaurant(restaurant)
                        .featureCode(request.getFeatureCode())
                        .build());

        flag.setEnabled(request.getEnabled());
        return toDto(featureFlagRepository.save(flag));
    }

    @Transactional
    public FeatureFlagResponse update(Long flagId, FeatureFlagRequest request) {
        RestaurantFeatureFlag flag = findEntityById(flagId);
        Long restaurantId = flag.getRestaurant().getId();

        var existing = featureFlagRepository.findByRestaurantIdAndFeatureCode(restaurantId, request.getFeatureCode());
        if (existing.isPresent() && !existing.get().getId().equals(flagId)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Feature code already exists for this restaurant: " + request.getFeatureCode()
            );
        }

        flag.setFeatureCode(request.getFeatureCode());
        flag.setEnabled(request.getEnabled());
        return toDto(featureFlagRepository.save(flag));
    }

    @Transactional(readOnly = true)
    public FeatureFlagResponse getById(Long flagId) {
        return toDto(findEntityById(flagId));
    }

    @Transactional(readOnly = true)
    public List<FeatureFlagResponse> getByRestaurantId(Long restaurantId) {
        restaurantService.findById(restaurantId);
        return featureFlagRepository.findByRestaurantIdOrderByFeatureCodeAsc(restaurantId)
                .stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public void delete(Long flagId) {
        featureFlagRepository.delete(findEntityById(flagId));
    }

    @Transactional
    public List<FeatureFlagResponse> applyTemplate(Long restaurantId, FeatureTemplate template) {
        Restaurant restaurant = restaurantService.findById(restaurantId);
        Map<FeatureCode, Boolean> preset = resolveTemplate(template);

        for (Map.Entry<FeatureCode, Boolean> entry : preset.entrySet()) {
            RestaurantFeatureFlag flag = featureFlagRepository
                    .findByRestaurantIdAndFeatureCode(restaurantId, entry.getKey())
                    .orElse(RestaurantFeatureFlag.builder()
                            .restaurant(restaurant)
                            .featureCode(entry.getKey())
                            .build());
            flag.setEnabled(entry.getValue());
            featureFlagRepository.save(flag);
        }

        return featureFlagRepository.findByRestaurantIdOrderByFeatureCodeAsc(restaurantId)
                .stream()
                .map(this::toDto)
                .toList();
    }

    private Map<FeatureCode, Boolean> resolveTemplate(FeatureTemplate template) {
        Map<FeatureCode, Boolean> preset = new EnumMap<>(FeatureCode.class);

        switch (template) {
            case BASIC -> {
                preset.put(FeatureCode.POS, false);
                preset.put(FeatureCode.BILL_PRINTING, false);
                preset.put(FeatureCode.TABLE_PAYMENT, false);
                preset.put(FeatureCode.MENU_IMAGES, true);
                preset.put(FeatureCode.CUSTOMER_SPLIT_BILL, false);
            }
            case PRO -> {
                preset.put(FeatureCode.POS, true);
                preset.put(FeatureCode.BILL_PRINTING, true);
                preset.put(FeatureCode.TABLE_PAYMENT, false);
                preset.put(FeatureCode.MENU_IMAGES, true);
                preset.put(FeatureCode.CUSTOMER_SPLIT_BILL, true);
            }
            case ENTERPRISE -> {
                preset.put(FeatureCode.POS, true);
                preset.put(FeatureCode.BILL_PRINTING, true);
                preset.put(FeatureCode.TABLE_PAYMENT, true);
                preset.put(FeatureCode.MENU_IMAGES, true);
                preset.put(FeatureCode.CUSTOMER_SPLIT_BILL, true);
            }
        }
        return preset;
    }

    private RestaurantFeatureFlag findEntityById(Long flagId) {
        return featureFlagRepository.findById(flagId)
                .orElseThrow(() -> new ResourceNotFoundException("RestaurantFeatureFlag", flagId));
    }

    private FeatureFlagResponse toDto(RestaurantFeatureFlag flag) {
        return FeatureFlagResponse.builder()
                .id(flag.getId())
                .restaurantId(flag.getRestaurant().getId())
                .featureCode(flag.getFeatureCode())
                .enabled(flag.getEnabled())
                .createdAt(flag.getCreatedAt())
                .updatedAt(flag.getUpdatedAt())
                .build();
    }
}
