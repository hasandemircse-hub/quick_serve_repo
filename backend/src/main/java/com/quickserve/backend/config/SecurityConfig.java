package com.quickserve.backend.config;

import com.quickserve.backend.security.JwtAuthFilter;
import com.quickserve.backend.security.UserDetailsServiceImpl;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final UserDetailsServiceImpl userDetailsService;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(cors -> {}) // CorsConfig bean'ini kullan
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // CORS preflight
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                // Herkese açık: QR ile müşteri girişi
                .requestMatchers("/customer/**").permitAll()
                // Auth endpointleri
                .requestMatchers("/auth/**").permitAll()
                // Swagger / Actuator
                .requestMatchers("/swagger-ui/**", "/api-docs/**", "/actuator/health").permitAll()
                // WebSocket handshake (SockJS + raw). JWT query param ile doğrulanır.
                .requestMatchers("/ws", "/ws/**").permitAll()
                // Sadece SUPERADMIN
                .requestMatchers("/superadmin/**").hasRole("SUPERADMIN")
                // Restoran admin + superadmin
                .requestMatchers("/admin/**").hasAnyRole("SUPERADMIN", "RESTAURANT_ADMIN")
                // Garson ekranı
                .requestMatchers("/waiter/**").hasAnyRole("SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "WAITER")
                // Mutfak ekranı
                .requestMatchers("/kitchen/**").hasAnyRole("SUPERADMIN", "RESTAURANT_ADMIN", "CHEF", "HEAD_WAITER")
                // Vale
                .requestMatchers("/valet/**").hasAnyRole("SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "VALET")
                // Geri kalan her şey kimlik doğrulaması gerektirir
                .anyRequest().authenticated()
            )
            .authenticationProvider(authenticationProvider())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public AuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
        provider.setUserDetailsService(userDetailsService);
        provider.setPasswordEncoder(passwordEncoder());
        return provider;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
