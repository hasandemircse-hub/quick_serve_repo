package com.quickserve.backend.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

/**
 * Netgsm SMS entegrasyonu.
 * TODO(NETGSM): Netgsm API dokümantasyonuna göre doğrulanmalı.
 * Şu an GET isteği ile gönderim yapılmaktadır.
 * Netgsm XML API veya REST API kullanılabilir.
 */
@Service
@Slf4j
public class SmsService {

    @Value("${app.sms.netgsm.api-url}")
    private String apiUrl;

    @Value("${app.sms.netgsm.usercode}")
    private String usercode;

    @Value("${app.sms.netgsm.password}")
    private String password;

    @Value("${app.sms.netgsm.msgheader}")
    private String msgheader;

    private final RestTemplate restTemplate = new RestTemplate();

    public void sendSms(String phone, String message) {
        try {
            String url = UriComponentsBuilder.fromHttpUrl(apiUrl)
                    .queryParam("usercode", usercode)
                    .queryParam("password", password)
                    .queryParam("gsmno", normalizePhone(phone))
                    .queryParam("message", message)
                    .queryParam("msgheader", msgheader)
                    .toUriString();

            String response = restTemplate.getForObject(url, String.class);
            log.info("SMS sent to {}: response={}", phone, response);

            if (response != null && response.startsWith("00")) {
                log.info("SMS successfully sent to {}", phone);
            } else {
                log.warn("SMS send failed to {}: {}", phone, response);
            }
        } catch (Exception e) {
            log.error("SMS send error to {}: {}", phone, e.getMessage(), e);
        }
    }

    public void sendSmsToMultiple(Iterable<String> phones, String message) {
        for (String phone : phones) {
            sendSms(phone, message);
        }
    }

    private String normalizePhone(String phone) {
        if (phone == null) return "";
        // +90 5XX XXX XX XX → 5XXXXXXXXX
        return phone.replaceAll("[^0-9]", "").replaceFirst("^90", "");
    }
}
