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
        // Geliştirmede Flutter web dev server rastgele portta çalışır.
        // CORS whitelist + localhost:* pattern ile origin'leri birleştiriyoruz.
        String[] configured = allowedOrigins.split(",");
        String[] patterns = new String[configured.length + 2];
        System.arraycopy(configured, 0, patterns, 0, configured.length);
        patterns[configured.length] = "http://localhost:*";
        patterns[configured.length + 1] = "https://localhost:*";

        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns(patterns)
                .withSockJS();
    }

    /*
     * WebSocket topic yapısı:
     *
     * /topic/restaurant/{restaurantId}/orders       → Mutfak + admin için yeni siparişler
     * /topic/restaurant/{restaurantId}/tables       → Admin için masa durumu
     * /topic/restaurant/{restaurantId}/calls        → Garson çağrıları
     * /topic/restaurant/{restaurantId}/edge_ops    → Edge senkron olay özeti (LWW / apply)
     * /topic/restaurant/{restaurantId}/edge_master → Master snapshot geçersiz; edge anında pull tetikler
     * /topic/restaurant/{restaurantId}/edge_nodes  → Edge node heartbeat / durum
     * /topic/session/{sessionToken}/status          → Müşteri sipariş durumu
     * /user/{username}/notifications               → Kullanıcıya özel bildirimler
     */
}
