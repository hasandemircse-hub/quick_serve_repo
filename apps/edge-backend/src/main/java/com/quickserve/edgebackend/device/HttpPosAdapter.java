package com.quickserve.edgebackend.device;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.Arrays;
import java.util.Map;

@Component
public class HttpPosAdapter implements PosAdapter {

    private final boolean enabled;
    private final String providerCode;
    private final String baseUrl;
    private final String chargePath;
    private final String bearerToken;
    private final String apiKeyHeader;
    private final String apiKeyValue;
    private final String responseSuccessField;
    private final String responseSuccessValue;
    private final String[] responseTxIdFields;
    private final String[] responseMessageFields;
    private final String[] responseErrorCodeFields;
    private final String responseRetryableField;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    public HttpPosAdapter(
            @Value("${app.edge.device.pos.http.enabled:false}") boolean enabled,
            @Value("${app.edge.device.pos.http.provider-code:http-pos}") String providerCode,
            @Value("${app.edge.device.pos.http.base-url:}") String baseUrl,
            @Value("${app.edge.device.pos.http.charge-path:/charge}") String chargePath,
            @Value("${app.edge.device.pos.http.bearer-token:}") String bearerToken,
            @Value("${app.edge.device.pos.http.api-key-header:X-API-Key}") String apiKeyHeader,
            @Value("${app.edge.device.pos.http.api-key-value:}") String apiKeyValue,
            @Value("${app.edge.device.pos.http.response.success-field:success}") String responseSuccessField,
            @Value("${app.edge.device.pos.http.response.success-value:true}") String responseSuccessValue,
            @Value("${app.edge.device.pos.http.response.tx-id-fields:transactionId,txId,id}") String responseTxIdFields,
            @Value("${app.edge.device.pos.http.response.message-fields:message,statusMessage}") String responseMessageFields,
            @Value("${app.edge.device.pos.http.response.error-code-fields:errorCode,code}") String responseErrorCodeFields,
            @Value("${app.edge.device.pos.http.response.retryable-field:retryable}") String responseRetryableField,
            @Value("${app.edge.device.pos.http.connect-timeout-ms:3000}") int connectTimeoutMs,
            @Value("${app.edge.device.pos.http.read-timeout-ms:8000}") int readTimeoutMs,
            RestTemplateBuilder restTemplateBuilder,
            ObjectMapper objectMapper
    ) {
        this.enabled = enabled;
        this.providerCode = providerCode;
        this.baseUrl = normalize(baseUrl);
        this.chargePath = chargePath == null || chargePath.isBlank() ? "/charge" : chargePath.trim();
        this.bearerToken = normalize(bearerToken);
        this.apiKeyHeader = apiKeyHeader == null || apiKeyHeader.isBlank() ? "X-API-Key" : apiKeyHeader.trim();
        this.apiKeyValue = normalize(apiKeyValue);
        this.responseSuccessField = normalizeOrDefault(responseSuccessField, "success");
        this.responseSuccessValue = normalizeOrDefault(responseSuccessValue, "true");
        this.responseTxIdFields = splitFields(responseTxIdFields, "transactionId", "txId", "id");
        this.responseMessageFields = splitFields(responseMessageFields, "message", "statusMessage");
        this.responseErrorCodeFields = splitFields(responseErrorCodeFields, "errorCode", "code");
        this.responseRetryableField = normalizeOrDefault(responseRetryableField, "retryable");
        this.restTemplate = restTemplateBuilder
                .setConnectTimeout(Duration.ofMillis(Math.max(connectTimeoutMs, 100)))
                .setReadTimeout(Duration.ofMillis(Math.max(readTimeoutMs, 500)))
                .build();
        this.objectMapper = objectMapper;
    }

    @Override
    public String providerCode() {
        return providerCode;
    }

    @Override
    public PosChargeResult charge(PosChargeRequest request) {
        if (!enabled) {
            throw new PosProviderException("provider_disabled", "HTTP POS adapter is disabled", false);
        }
        if (baseUrl == null || baseUrl.isBlank()) {
            throw new PosProviderException("provider_misconfigured", "HTTP POS base URL is missing", false);
        }
        if (request.amount() == null || request.amount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new PosProviderException("invalid_amount", "Amount must be positive", false);
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        if (bearerToken != null && !bearerToken.isBlank()) {
            headers.setBearerAuth(bearerToken);
        }
        if (apiKeyValue != null && !apiKeyValue.isBlank()) {
            headers.set(apiKeyHeader, apiKeyValue);
        }
        if (request.idempotencyKey() != null && !request.idempotencyKey().isBlank()) {
            headers.set("Idempotency-Key", request.idempotencyKey().trim());
        }

        Map<String, Object> payload = Map.of(
                "paymentId", request.paymentId(),
                "amount", request.amount(),
                "currency", request.currency(),
                "orderId", request.orderId()
        );

        String url = buildUrl(baseUrl, chargePath);
        try {
            ResponseEntity<String> response = restTemplate.exchange(
                    url,
                    HttpMethod.POST,
                    new HttpEntity<>(payload, headers),
                    String.class
            );
            return mapSuccessResponse(response.getBody());
        } catch (HttpStatusCodeException ex) {
            boolean retryable = ex.getStatusCode().is5xxServerError() || ex.getStatusCode().value() == 429;
            throw new PosProviderException(
                    "provider_http_" + ex.getStatusCode().value(),
                    ex.getResponseBodyAsString() == null || ex.getResponseBodyAsString().isBlank()
                            ? "HTTP POS provider returned " + ex.getStatusCode().value()
                            : ex.getResponseBodyAsString(),
                    retryable
            );
        } catch (ResourceAccessException ex) {
            throw new PosProviderException("provider_unreachable", "Cannot reach HTTP POS provider", true);
        }
    }

    @Override
    public boolean isHealthy() {
        return enabled && baseUrl != null && !baseUrl.isBlank();
    }

    private PosChargeResult mapSuccessResponse(String rawBody) {
        if (rawBody == null || rawBody.isBlank()) {
            return PosChargeResult.success(providerCode, null, "http_pos_charge_ok");
        }
        try {
            Map<String, Object> map = objectMapper.readValue(rawBody, new TypeReference<>() {});
            boolean success = evaluateSuccess(map);
            String transactionId = firstMapped(map, responseTxIdFields);
            String message = firstMapped(map, responseMessageFields);
            if (message == null || message.isBlank()) {
                message = "http_pos_charge_ok";
            }
            String errorCode = firstMapped(map, responseErrorCodeFields);
            boolean retryable = Boolean.TRUE.equals(map.get(responseRetryableField));
            if (success) {
                return PosChargeResult.success(providerCode, transactionId, message);
            }
            return PosChargeResult.failure(providerCode, message, errorCode == null ? "provider_declined" : errorCode, retryable);
        } catch (Exception ex) {
            return PosChargeResult.success(providerCode, null, "http_pos_charge_ok");
        }
    }

    private String buildUrl(String base, String path) {
        String normalizedBase = base.endsWith("/") ? base.substring(0, base.length() - 1) : base;
        String normalizedPath = path.startsWith("/") ? path : "/" + path;
        return normalizedBase + normalizedPath;
    }

    private String normalize(String value) {
        return value == null ? null : value.trim();
    }

    private String normalizeOrDefault(String value, String fallback) {
        String normalized = normalize(value);
        return normalized == null || normalized.isBlank() ? fallback : normalized;
    }

    private String[] splitFields(String csv, String... fallback) {
        String normalized = normalize(csv);
        if (normalized == null || normalized.isBlank()) {
            return fallback;
        }
        return Arrays.stream(normalized.split(","))
                .map(String::trim)
                .filter(s -> !s.isBlank())
                .toArray(String[]::new);
    }

    private String firstMapped(Map<String, Object> map, String[] fields) {
        for (String field : fields) {
            Object raw = map.get(field);
            String value = raw == null ? null : raw.toString();
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }

    private boolean evaluateSuccess(Map<String, Object> map) {
        Object raw = map.get(responseSuccessField);
        if (raw == null) {
            return true;
        }
        if (raw instanceof Boolean boolValue) {
            return boolValue;
        }
        String normalizedRaw = raw.toString().trim();
        if (normalizedRaw.isBlank()) {
            return true;
        }
        if ("true".equalsIgnoreCase(responseSuccessValue) || "false".equalsIgnoreCase(responseSuccessValue)) {
            return Boolean.parseBoolean(normalizedRaw);
        }
        return normalizedRaw.equalsIgnoreCase(responseSuccessValue);
    }
}
