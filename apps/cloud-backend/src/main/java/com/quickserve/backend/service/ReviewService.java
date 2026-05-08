package com.quickserve.backend.service;

import com.quickserve.backend.dto.review.ReviewRequest;
import com.quickserve.backend.dto.review.ReviewResponse;
import com.quickserve.backend.entity.Review;
import com.quickserve.backend.entity.TableSession;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final TableSessionRepository sessionRepository;
    private final UserRepository userRepository;

    @Transactional
    public ReviewResponse createReview(String sessionToken, ReviewRequest request) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));

        if (reviewRepository.findByTableSessionId(session.getId()).isPresent()) {
            throw new BusinessException("Bu oturum için zaten değerlendirme yapılmış");
        }

        // O masaya son atanan garsonı bul
        User waiter = null;
        // TODO: Aktif oturumdaki siparişlere atanan garsonı burada belirle

        Review review = Review.builder()
                .tableSession(session)
                .restaurant(session.getTable().getRestaurant())
                .assignedWaiter(waiter)
                .rating(request.getRating())
                .comment(request.getComment())
                .build();

        return toDto(reviewRepository.save(review));
    }

    @Transactional(readOnly = true)
    public List<ReviewResponse> getRestaurantReviews(Long restaurantId) {
        return reviewRepository.findByRestaurantIdOrderByCreatedAtDesc(restaurantId)
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public List<ReviewResponse> getWaiterReviews(Long waiterId) {
        return reviewRepository.findByAssignedWaiterIdOrderByCreatedAtDesc(waiterId)
                .stream().map(this::toDto).toList();
    }

    private ReviewResponse toDto(Review r) {
        return ReviewResponse.builder()
                .id(r.getId())
                .rating(r.getRating())
                .comment(r.getComment())
                .waiterName(r.getAssignedWaiter() != null ? r.getAssignedWaiter().getFullName() : null)
                .createdAt(r.getCreatedAt())
                .build();
    }
}
