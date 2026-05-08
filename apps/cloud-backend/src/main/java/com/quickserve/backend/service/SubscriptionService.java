package com.quickserve.backend.service;

import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.entity.Subscription;
import com.quickserve.backend.enums.SubscriptionStatus;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.RestaurantRepository;
import com.quickserve.backend.repository.SubscriptionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class SubscriptionService {

    private final SubscriptionRepository subscriptionRepository;
    private final RestaurantRepository restaurantRepository;
    private final RestaurantService restaurantService;
    private final NotificationService notificationService;
    private final SmsService smsService;
    private final EmailService emailService;

    @Transactional
    public Subscription createSubscription(Long restaurantId, BigDecimal amount, LocalDate dueDate,
                                            LocalDate periodStart, LocalDate periodEnd) {
        Restaurant restaurant = restaurantService.findById(restaurantId);
        return subscriptionRepository.save(Subscription.builder()
                .restaurant(restaurant)
                .amount(amount)
                .dueDate(dueDate)
                .periodStart(periodStart)
                .periodEnd(periodEnd)
                .isPaid(false)
                .build());
    }

    @Transactional
    public void markPaid(Long subscriptionId, String paymentReference) {
        Subscription sub = subscriptionRepository.findById(subscriptionId)
                .orElseThrow(() -> new ResourceNotFoundException("Subscription", subscriptionId));

        sub.setIsPaid(true);
        sub.setPaidAt(LocalDateTime.now());
        sub.setPaymentReference(paymentReference);
        subscriptionRepository.save(sub);

        // Restoranın abonelik durumunu aktifle
        Restaurant r = sub.getRestaurant();
        r.setSubscriptionStatus(SubscriptionStatus.ACTIVE);
        if (sub.getPeriodEnd() != null) {
            r.setSubscriptionExpiresAt(sub.getPeriodEnd().atTime(23, 59, 59));
        }
        restaurantRepository.save(r);
        log.info("Subscription marked paid for restaurant {}", r.getName());
    }

    @Transactional(readOnly = true)
    public List<Subscription> getRestaurantSubscriptions(Long restaurantId) {
        return subscriptionRepository.findByRestaurantIdOrderByDueDateDesc(restaurantId);
    }

    /**
     * Her gece 09:00'da vadesi geçmiş ödemeler için bildirim gönder.
     */
    @Scheduled(cron = "0 0 9 * * *")
    @Transactional
    public void checkOverduePayments() {
        List<Subscription> overdue = subscriptionRepository
                .findByIsPaidFalseAndDueDateBeforeAndOverdueNotifiedFalse(LocalDate.now());

        for (Subscription sub : overdue) {
            Restaurant r = sub.getRestaurant();
            String msg = String.format("QuickServe abonelik ödemesi gecikti. Restoran: %s, Tutar: %s TL, Vade: %s",
                    r.getName(), sub.getAmount(), sub.getDueDate());

            // Superadmin SMS + mail
            notificationService.notifySuperadmins("PAYMENT_OVERDUE",
                    "Ödeme Gecikmesi: " + r.getName(),
                    msg, null);

            // Restoran admin'e mail
            if (r.getEmail() != null) {
                emailService.sendPaymentOverdueNotice(r.getEmail(), r.getName(), sub.getAmount().toString());
            }

            // Restoran sahibine SMS
            if (r.getPhone() != null) {
                smsService.sendSms(r.getPhone(), "QuickServe abonelik ödemeniz gecikti. Lütfen ödeme yapınız.");
            }

            sub.setOverdueNotified(true);
            subscriptionRepository.save(sub);
        }
    }

    /**
     * Her gece demo ve aktif aboneliklerin vade kontrolü.
     */
    @Scheduled(cron = "0 0 0 * * *")
    @Transactional
    public void checkExpirations() {
        // Demo süresi dolan restoranları expire et
        restaurantRepository.findExpiredDemoRestaurants(LocalDateTime.now()).forEach(r -> {
            r.setSubscriptionStatus(SubscriptionStatus.EXPIRED);
            restaurantRepository.save(r);
            log.info("Restaurant demo expired: {}", r.getName());
        });

        // Aktif aboneliği dolan restoranlar
        restaurantRepository.findExpiredActiveSubscriptions(LocalDateTime.now()).forEach(r -> {
            r.setSubscriptionStatus(SubscriptionStatus.EXPIRED);
            restaurantRepository.save(r);
            log.info("Restaurant subscription expired: {}", r.getName());
        });
    }
}
