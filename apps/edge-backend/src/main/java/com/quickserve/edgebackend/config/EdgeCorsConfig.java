package com.quickserve.edgebackend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

@Configuration
public class EdgeCorsConfig {

    @Value("${app.edge.cors.allowed-origin-patterns:http://localhost:*,http://127.0.0.1:*,https://localhost:*,https://127.0.0.1:*}")
    private String allowedOriginPatterns;

    @Bean
    public CorsFilter edgeCorsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        List<String> patterns = new ArrayList<>(
                Arrays.stream(allowedOriginPatterns.split(","))
                        .map(String::trim)
                        .filter(StringUtils::hasText)
                        .toList());
        if (patterns.isEmpty()) {
            patterns = List.of("http://localhost:*", "http://127.0.0.1:*");
        }
        config.setAllowedOriginPatterns(patterns);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return new CorsFilter(source);
    }
}
