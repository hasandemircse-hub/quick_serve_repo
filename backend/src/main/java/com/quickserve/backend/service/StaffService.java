package com.quickserve.backend.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.quickserve.backend.dto.user.UserRequest;
import com.quickserve.backend.dto.user.UserResponse;
import com.quickserve.backend.dto.user.WaiterPerformanceResponse;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.PaymentRepository;
import com.quickserve.backend.repository.ReviewRepository;
import com.quickserve.backend.repository.UserRepository;
import com.quickserve.backend.repository.WaiterCallRepository;
import com.quickserve.backend.security.SecurityUtils;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class StaffService {

    private final UserRepository userRepository;
    private final ReviewRepository reviewRepository;
    private final PaymentRepository paymentRepository;
    private final WaiterCallRepository waiterCallRepository;
    private final RestaurantService restaurantService;
    private final PasswordEncoder passwordEncoder;
    private final SecurityUtils securityUtils;

    @Transactional
    public UserResponse createStaff(Long restaurantId, UserRequest request) {
        String username = request.getUsername().toLowerCase();
        request.setUsername(username);
        if (userRepository.existsByUsername(username)) {
            throw new BusinessException("Bu kullanıcı adı zaten kullanımda: " + username);
        }
        if (request.getRole() == UserRole.SUPERADMIN) {
            throw new BusinessException("SUPERADMIN rolü bu endpoint ile oluşturulamaz");
        }
        if (request.getRole() == UserRole.RESTAURANT_ADMIN) {
            // Bir restoranda sadece bir RESTAURANT_ADMIN olabilir
            if (userRepository.existsByRestaurantIdAndRole(restaurantId, UserRole.RESTAURANT_ADMIN)) {
                throw new BusinessException("Bu restoran için zaten bir yönetici mevcut");
            }
        }
        Restaurant restaurant = restaurantService.findById(restaurantId);
        User user = User.builder()
                .restaurant(restaurant)
                .username(request.getUsername())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .email(request.getEmail())
                .phone(request.getPhone())
                .role(request.getRole())
                .isActive(true)
                .isOnLeave(false)
                .build();
        return toDto(userRepository.save(user));
    }

    @Transactional
    public UserResponse updateStaff(Long userId, UserRequest request) {
        User user = findById(userId);
        if (request.getFullName() != null) user.setFullName(request.getFullName());
        if (request.getEmail() != null) user.setEmail(request.getEmail());
        if (request.getPhone() != null) user.setPhone(request.getPhone());
        if (request.getPassword() != null && !request.getPassword().isBlank()) {
            user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        }
        if (request.getRole() != null && request.getRole() != UserRole.SUPERADMIN) {
            user.setRole(request.getRole());
        }
        return toDto(userRepository.save(user));
    }

    @Transactional
    public void setLeave(Long userId, boolean onLeave, String reason) {
        User user = findById(userId);
        user.setIsOnLeave(onLeave);
        user.setLeaveReason(reason);
        userRepository.save(user);
    }

    @Transactional
    public void setActive(Long userId, boolean active) {
        User user = findById(userId);
        user.setIsActive(active);
        userRepository.save(user);
    }

    @Transactional
    public void deleteStaff(Long userId) {
        User currentUser = securityUtils.getCurrentUser();
        if (currentUser.getId().equals(userId)) {
            throw new BusinessException("Kendi hesabınızı silemezsiniz");
        }
        User user = findById(userId);
        userRepository.delete(user);
    }

    @Transactional(readOnly = true)
    public List<UserResponse> getStaff(Long restaurantId) {
        return userRepository.findByRestaurantIdOrderByFullName(restaurantId)
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public WaiterPerformanceResponse getWaiterPerformance(Long waiterId) {
        User waiter = findById(waiterId);
        LocalDateTime from = LocalDateTime.now().minusMonths(1);
        LocalDateTime to = LocalDateTime.now();

        return WaiterPerformanceResponse.builder()
                .userId(waiter.getId())
                .fullName(waiter.getFullName())
                .tablesServed(reviewRepository.countByAssignedWaiterId(waiterId))
                .totalTipsEarned(paymentRepository.sumTipsByWaiter(waiterId, from, to))
                .averageRating(reviewRepository.averageRatingByWaiter(waiterId))
                .totalReviews(reviewRepository.countByAssignedWaiterId(waiterId))
                .callsHandled(waiterCallRepository.countByAssignedToId(waiterId))
                .build();
    }

    public User findById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
    }

    public UserResponse toDto(User u) {
        return UserResponse.builder()
                .id(u.getId())
                .username(u.getUsername())
                .fullName(u.getFullName())
                .email(u.getEmail())
                .phone(u.getPhone())
                .role(u.getRole())
                .isActive(u.getIsActive())
                .isOnLeave(u.getIsOnLeave())
                .leaveReason(u.getLeaveReason())
                .restaurantId(u.getRestaurant() != null ? u.getRestaurant().getId() : null)
                .createdAt(u.getCreatedAt())
                .lastLoginAt(u.getLastLoginAt())
                .build();
    }
}
