package com.quickserve.edgebackend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Cloud ile aynı STOMP/SockJS uç noktası ({@code /ws}); edge-frontend tarayıcıdan
 * bağlanırken 404 önlenir. Edge şu an bu kanaldan olay yayınlamıyor; ekranlar yine
 * REST ile çalışır, reconnect gürültüsü kesilir.
 */
@Configuration
@EnableWebSocketMessageBroker
public class EdgeWebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Value("${app.edge.cors.allowed-origin-patterns:http://localhost:*,http://127.0.0.1:*,https://localhost:*,https://127.0.0.1:*}")
    private String allowedOriginPatterns;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic", "/queue");
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        List<String> patterns = new ArrayList<>(
                Arrays.stream(allowedOriginPatterns.split(","))
                        .map(String::trim)
                        .filter(s -> !s.isEmpty())
                        .toList());
        if (patterns.isEmpty()) {
            patterns = List.of("http://localhost:*", "http://127.0.0.1:*");
        }
        registry.addEndpoint("/ws").setAllowedOriginPatterns(patterns.toArray(String[]::new)).withSockJS();
    }
}
