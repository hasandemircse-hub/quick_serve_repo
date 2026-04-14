package com.quickserve.backend.service;

import com.quickserve.backend.dto.restaurant.RestaurantRequest;
import com.quickserve.backend.dto.restaurant.RestaurantResponse;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.enums.SubscriptionStatus;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class RestaurantService {

    private final RestaurantRepository restaurantRepository;
    private final UserRepository userRepository;
    private final PaymentSplitRepository paymentSplitRepository;
    private final PaymentRepository paymentRepository;
    private final OrderItemRepository orderItemRepository;
    private final OrderRepository orderRepository;
    private final ReviewRepository reviewRepository;
    private final WaiterCallRepository waiterCallRepository;
    private final NotificationRepository notificationRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final TableSessionRepository tableSessionRepository;
    private final MenuItemRepository menuItemRepository;
    private final MenuCategoryRepository menuCategoryRepository;
    private final RestaurantTableRepository restaurantTableRepository;

    @Transactional
    public RestaurantResponse create(RestaurantRequest request) {
        Restaurant restaurant = Restaurant.builder()
                .name(request.getName())
                .phone(request.getPhone())
                .email(request.getEmail())
                .address(request.getAddress())
                .logoUrl(request.getLogoUrl())
                .backgroundImageUrl(request.getBackgroundImageUrl())
                .primaryColor(request.getPrimaryColor())
                .fontFamily(request.getFontFamily())
                .ibanNumber(request.getIbanNumber())
                .iyzicoApiKey(request.getIyzicoApiKey())
                .iyzicoSecretKey(request.getIyzicoSecretKey())
                .iyzicoBaseUrl(request.getIyzicoBaseUrl())
                .subscriptionStatus(SubscriptionStatus.DEMO)
                .build();
        return toDto(restaurantRepository.save(restaurant));
    }

    @Transactional
    @CacheEvict(value = "restaurantInfo", key = "#id")
    public RestaurantResponse update(Long id, RestaurantRequest request) {
        Restaurant r = findById(id);
        r.setName(request.getName());
        r.setPhone(request.getPhone());
        r.setEmail(request.getEmail());
        r.setAddress(request.getAddress());
        if (request.getLogoUrl() != null) r.setLogoUrl(request.getLogoUrl());
        if (request.getBackgroundImageUrl() != null) r.setBackgroundImageUrl(request.getBackgroundImageUrl());
        if (request.getPrimaryColor() != null) r.setPrimaryColor(request.getPrimaryColor());
        if (request.getFontFamily() != null) r.setFontFamily(request.getFontFamily());
        if (request.getIbanNumber() != null) r.setIbanNumber(request.getIbanNumber());
        if (request.getIyzicoApiKey() != null) r.setIyzicoApiKey(request.getIyzicoApiKey());
        if (request.getIyzicoSecretKey() != null) r.setIyzicoSecretKey(request.getIyzicoSecretKey());
        if (request.getIyzicoBaseUrl() != null) r.setIyzicoBaseUrl(request.getIyzicoBaseUrl());
        return toDto(restaurantRepository.save(r));
    }

    @Cacheable(value = "restaurantInfo", key = "#id")
    @Transactional(readOnly = true)
    public RestaurantResponse getById(Long id) {
        return toDto(findById(id));
    }

    @Transactional(readOnly = true)
    public List<RestaurantResponse> getAll() {
        return restaurantRepository.findAllByOrderByIsActiveDescCreatedAtDesc()
                .stream().map(this::toDto).toList();
    }

    @Transactional
    @CacheEvict(value = "restaurantInfo", key = "#id")
    public void setActive(Long id, boolean active) {
        Restaurant r = findById(id);
        r.setIsActive(active);
        restaurantRepository.save(r);
    }

    @Transactional
    @CacheEvict(value = "restaurantInfo", key = "#id")
    public void setSubscriptionStatus(Long id, SubscriptionStatus status,
                                       LocalDateTime expiresAt, LocalDateTime demoExpiresAt) {
        Restaurant r = findById(id);
        r.setSubscriptionStatus(status);
        if (expiresAt != null) r.setSubscriptionExpiresAt(expiresAt);
        if (demoExpiresAt != null) r.setDemoExpiresAt(demoExpiresAt);
        restaurantRepository.save(r);
    }

    @Transactional
    public void delete(Long id) {
        findById(id); // varlık kontrolü
        // FK bağımlılık sırasına göre sil (yaprak → kök)
        paymentSplitRepository.deleteByRestaurantId(id);
        paymentRepository.deleteByRestaurantId(id);
        orderItemRepository.deleteByRestaurantId(id);
        orderRepository.deleteByRestaurantId(id);
        reviewRepository.deleteByRestaurantId(id);
        waiterCallRepository.deleteByRestaurantId(id);
        notificationRepository.deleteByRestaurantId(id);
        subscriptionRepository.deleteByRestaurantId(id);
        tableSessionRepository.deleteByRestaurantId(id);
        menuItemRepository.deleteNoteOptionsByRestaurantId(id);
        menuItemRepository.deleteByRestaurantId(id);
        menuCategoryRepository.deleteByRestaurantId(id);
        restaurantTableRepository.deleteByRestaurantId(id);
        userRepository.deleteByRestaurantId(id);
        restaurantRepository.deleteById(id);
    }

    public Restaurant findById(Long id) {
        return restaurantRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Restaurant", id));
    }

    public RestaurantResponse toDto(Restaurant r) {
        return RestaurantResponse.builder()
                .id(r.getId())
                .name(r.getName())
                .phone(r.getPhone())
                .email(r.getEmail())
                .address(r.getAddress())
                .logoUrl(r.getLogoUrl())
                .backgroundImageUrl(r.getBackgroundImageUrl())
                .primaryColor(r.getPrimaryColor())
                .fontFamily(r.getFontFamily())
                .isActive(r.getIsActive())
                .subscriptionStatus(r.getSubscriptionStatus())
                .subscriptionExpiresAt(r.getSubscriptionExpiresAt())
                .demoExpiresAt(r.getDemoExpiresAt())
                .subscriptionValid(r.isSubscriptionValid())
                .createdAt(r.getCreatedAt())
                .staffCount(userRepository.countByRestaurantId(r.getId()))
                .build();
    }
}
