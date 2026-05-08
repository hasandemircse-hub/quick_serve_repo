package com.quickserve.edgebackend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;
import java.util.Map;

@Service
public class CloudBridgeService {

    private final RestClient restClient;
    private final String bridgeJwtToken;

    public CloudBridgeService(
            @Value("${app.edge.cloud-base-url:http://localhost:8080/api}") String cloudBaseUrl,
            @Value("${app.edge.bridge-jwt-token:}") String bridgeJwtToken
    ) {
        this.restClient = RestClient.builder().baseUrl(cloudBaseUrl).build();
        this.bridgeJwtToken = bridgeJwtToken == null ? "" : bridgeJwtToken.trim();
    }

    public boolean isBridgeConfigured() {
        return !bridgeJwtToken.isBlank();
    }

    public List<Map<String, Object>> fetchWaiterTables() {
        return restClient.get()
                .uri("/waiter/tables")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + bridgeJwtToken)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {});
    }

    public List<Map<String, Object>> fetchKitchenOrders() {
        return restClient.get()
                .uri("/kitchen/orders")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + bridgeJwtToken)
                .accept(MediaType.APPLICATION_JSON)
                .retrieve()
                .body(new ParameterizedTypeReference<List<Map<String, Object>>>() {});
    }

    public boolean pushEdgeEvent(String eventId, String eventType, String payloadJson) {
        restClient.post()
                .uri("/edge/sync/events")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + bridgeJwtToken)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of(
                        "eventId", eventId,
                        "eventType", eventType,
                        "payloadJson", payloadJson
                ))
                .retrieve()
                .toBodilessEntity();
        return true;
    }
}
