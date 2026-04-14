package com.quickserve.backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Value("${app.cors.allowed-origins}")
    private String allowedOrigins;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        // Sunucudan istemciye mesaj prefix'i
        registry.enableSimpleBroker("/topic", "/queue");
        // İstemciden sunucuya mesaj prefix'i
        registry.setApplicationDestinationPrefixes("/app");
        // Kullanıcıya özel mesajlar
        registry.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns(allowedOrigins.split(","))
                .withSockJS();
    }

    /*
     * WebSocket topic yapısı:
     *
     * /topic/restaurant/{restaurantId}/orders       → Mutfak + admin için yeni siparişler
     * /topic/restaurant/{restaurantId}/tables       → Admin için masa durumu
     * /topic/restaurant/{restaurantId}/calls        → Garson çağrıları
     * /topic/session/{sessionToken}/status          → Müşteri sipariş durumu
     * /user/{username}/notifications               → Kullanıcıya özel bildirimler
     */
}
