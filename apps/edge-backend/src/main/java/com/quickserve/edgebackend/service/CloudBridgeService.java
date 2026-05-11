package com.quickserve.edgebackend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.socket.WebSocketHttpHeaders;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class CloudBridgeService {

    private final RestClient restClient;
    private final String cloudBaseUrl;
    private final String bridgeJwtToken;
    private final boolean skipCloudJwt;
    private final long edgeRestaurantId;

    public CloudBridgeService(
            @Value("${app.edge.cloud-base-url:http://localhost:8080/api}") String cloudBaseUrl,
            @Value("${app.edge.bridge-jwt-token:}") String bridgeJwtToken,
            @Value("${app.edge.skip-cloud-jwt:false}") boolean skipCloudJwt,
            @Value("${app.edge.restaurant-id:0}") long edgeRestaurantId
    ) {
        this.cloudBaseUrl = cloudBaseUrl.trim();
        this.restClient = RestClient.builder().baseUrl(this.cloudBaseUrl).build();
        this.bridgeJwtToken = normalizeBridgeJwt(bridgeJwtToken);
        this.skipCloudJwt = skipCloudJwt;
        this.edgeRestaurantId = edgeRestaurantId;
    }

    public String getCloudBaseUrl() {
        return cloudBaseUrl;
    }

    public boolean skipCloudJwt() {
        return skipCloudJwt;
    }

    /**
     * Canlı cloud okuma/yazma denenecek mi? Lab modunda JWT olmadan da true olur (cloud tarafında permit gerekir).
     */
    public boolean shouldTryCloudLive() {
        return skipCloudJwt || (isBridgeConfigured() && bridgeJwtLooksPlausible());
    }

    /** .env tırnak/BOM ve yanlışlıkla yapıştırılan satır sonlarını temizler. */
    static String normalizeBridgeJwt(String raw) {
        if (raw == null) {
            return "";
        }
        String t = raw.trim();
        if (t.startsWith("\uFEFF")) {
            t = t.substring(1).trim();
        }
        if (t.length() >= 2
                && ((t.startsWith("\"") && t.endsWith("\"")) || (t.startsWith("'") && t.endsWith("'")))) {
            t = t.substring(1, t.length() - 1).trim();
        }
        // Tek satır olması gerekir; bazen editör içi kırılım kopyalanır
        t = t.replace("\r", "").replace("\n", "").trim();
        return t;
    }

    public boolean isBridgeConfigured() {
        return !bridgeJwtToken.isBlank();
    }

    /**
     * Enrollment secrets are random alphanumeric; JWTs are three dot-separated base64url segments
     * and typically start with "ey" (base64 of JSON header). Wrong paste → cloud returns 403.
     */
    public boolean bridgeJwtLooksPlausible() {
        if (bridgeJwtToken.isBlank()) {
            return false;
        }
        long dots = bridgeJwtToken.chars().filter(c -> c == '.').count();
        if (dots < 2) {
            return false;
        }
        // Standart HS256 header JSON → base64 genelde "eyJ" ile başlar
        return bridgeJwtToken.startsWith("ey");
    }

    /** cloud-probe: tam token göstermeden neden şekil kontrolü düştüğünü anlatır. */
    public Map<String, Object> bridgeJwtDiagnostics() {
        Map<String, Object> m = new LinkedHashMap<>();
        String t = bridgeJwtToken;
        m.put("length", t.length());
        m.put("dotCount", t.chars().filter(c -> c == '.').count());
        m.put("prefix4", t.length() >= 4 ? t.substring(0, 4) : t);
        boolean shortAlphanumeric = t.length() >= 20 && t.length() <= 40 && t.chars().noneMatch(c -> c == '.');
        m.put("looksLikeEnrollmentCode", shortAlphanumeric);
        m.put("startsWithEy", t.startsWith("ey"));
        if (skipCloudJwt) {
            m.put("hint", "EDGE_SKIP_CLOUD_JWT=true: Authorization gönderilmez; cloud VM'de QUICKSERVE_DEV_INSECURE_EDGE_BRIDGE=true olmalı.");
        } else if (shortAlphanumeric) {
            m.put("hint", "Bu uzunluk/nokta sayısı enrollment (kısa) koda benziyor; claim ile gelen bridgeJwtToken yapıştır.");
        } else if (t.chars().filter(c -> c == '.').count() < 2) {
            m.put("hint", "JWT üç parça ve en az iki nokta içerir; kopyalamada satır kırığı veya eksik parça olabilir.");
        } else if (!t.startsWith("ey")) {
            m.put("hint", "Geçerli JWT genelde eyJ ile başlar; başına boşluk/BOM veya yanlış metin yapışmış olabilir.");
        } else {
            m.put("hint", "Şekil uygun görünüyor.");
        }
        return m;
    }

    private void applyBearerIfPresent(RestClient.RequestHeadersSpec<?> spec) {
        if (!skipCloudJwt && !bridgeJwtToken.isBlank()) {
            spec.header(HttpHeaders.AUTHORIZATION, "Bearer " + bridgeJwtToken);
        }
    }

    /** STOMP / SockJS el sıkışması için Authorization header. */
    public void stampAuth(WebSocketHttpHeaders headers) {
        if (!skipCloudJwt && bridgeJwtLooksPlausible()) {
            headers.add(HttpHeaders.AUTHORIZATION, "Bearer " + bridgeJwtToken);
        }
    }

    public List<Map<String, Object>> fetchWaiterTables() {
        var spec = restClient.get()
                .uri("/waiter/tables")
                .accept(MediaType.APPLICATION_JSON);
        applyBearerIfPresent(spec);
        return spec.retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {});
    }

    public Map<String, Object> fetchWaiterMenuFromCloud() {
        var spec = restClient.get()
                .uri("/waiter/menu")
                .accept(MediaType.APPLICATION_JSON);
        applyBearerIfPresent(spec);
        return spec.retrieve()
                .body(new ParameterizedTypeReference<Map<String, Object>>() {});
    }

    public List<Map<String, Object>> fetchKitchenOrders() {
        var spec = restClient.get()
                .uri("/kitchen/orders")
                .accept(MediaType.APPLICATION_JSON);
        applyBearerIfPresent(spec);
        return spec.retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {});
    }

    /**
     * Tam restoran görüntüsü (masa, menü, personel, siparişler, çağrılar). SUPERADMIN köprüsü için {@code restaurantId} gönderilir.
     */
    public Map<String, Object> fetchBootstrapSnapshot(Long restaurantId) {
        String uri = (restaurantId != null && restaurantId > 0)
                ? "/edge/bootstrap/snapshot?restaurantId=" + restaurantId
                : "/edge/bootstrap/snapshot";
        var spec = restClient.get()
                .uri(uri)
                .accept(MediaType.APPLICATION_JSON);
        applyBearerIfPresent(spec);
        return spec.retrieve()
                .body(new ParameterizedTypeReference<Map<String, Object>>() {});
    }

    /**
     * Cloud'da uygulanmış edge olayları (cursor).
     *
     * @param sinceId exclusive; 0 veya negatif ise since gönderilmez
     */
    public String fetchOpsChangesRaw(long sinceId, int limit) {
        try {
            StringBuilder uri = new StringBuilder("/edge/ops/changes?restaurantId=").append(edgeRestaurantId);
            uri.append("&limit=").append(limit);
            if (sinceId > 0) {
                uri.append("&since=").append(sinceId);
            }
            var spec = restClient.get()
                    .uri(uri.toString())
                    .accept(MediaType.APPLICATION_JSON);
            applyBearerIfPresent(spec);
            return spec.retrieve()
                    .body(String.class);
        } catch (RestClientException ex) {
            return null;
        }
    }

    public void postHeartbeat(long restaurantId, String nodeName, String lastOutboxFlushAtUtcIso) {
        var body = new LinkedHashMap<String, Object>();
        body.put("restaurantId", restaurantId);
        body.put("nodeName", nodeName);
        if (lastOutboxFlushAtUtcIso != null && !lastOutboxFlushAtUtcIso.isBlank()) {
            body.put("lastOutboxFlushAtUtc", lastOutboxFlushAtUtcIso);
        }
        var spec = restClient.post()
                .uri("/edge/nodes/heartbeat")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body);
        applyBearerIfPresent(spec);
        spec.retrieve()
                .toBodilessEntity();
    }

    public long configuredRestaurantId() {
        return edgeRestaurantId;
    }

    public boolean pushEdgeEvent(String eventId, String eventType, String payloadJson) {
        var body = new LinkedHashMap<String, Object>();
        body.put("eventId", eventId);
        body.put("eventType", eventType);
        body.put("payloadJson", payloadJson != null ? payloadJson : "");
        if (skipCloudJwt && edgeRestaurantId > 0) {
            body.put("restaurantId", edgeRestaurantId);
        }
        var spec = restClient.post()
                .uri("/edge/sync/events")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body);
        applyBearerIfPresent(spec);
        spec.retrieve()
                .toBodilessEntity();
        return true;
    }
}
