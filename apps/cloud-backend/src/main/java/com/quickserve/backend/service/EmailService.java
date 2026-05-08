package com.quickserve.backend.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;

    @Value("${app.mail.from}")
    private String fromAddress;

    @Async
    public void sendSimple(String to, String subject, String body) {
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(fromAddress);
            message.setTo(to);
            message.setSubject(subject);
            message.setText(body);
            mailSender.send(message);
            log.info("Email sent to {}: {}", to, subject);
        } catch (Exception e) {
            log.error("Email send error to {}: {}", to, e.getMessage(), e);
        }
    }

    @Async
    public void sendPaymentOverdueNotice(String to, String restaurantName, String amount) {
        String subject = "QuickServe - Ödeme Gecikmesi Bildirimi";
        String body = String.format(
                "Sayın %s yöneticisi,\n\n" +
                "QuickServe abonelik ödemenizdeki %s TL tutarındaki fatura vadesini geçirmiştir.\n" +
                "Lütfen en kısa sürede ödeme yapınız.\n\n" +
                "Ödeme Hesabı: IBAN bilgisi için sistem üzerinden kontrol ediniz.\n\n" +
                "QuickServe Ekibi",
                restaurantName, amount);
        sendSimple(to, subject, body);
    }

    @Async
    public void sendSecurityAlert(String to, String details) {
        String subject = "[UYARI] QuickServe Güvenlik Uyarısı";
        String body = "Güvenlik uyarısı tespit edildi:\n\n" + details;
        sendSimple(to, subject, body);
    }
}
