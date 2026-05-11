package com.quickserve.backend.config;

import com.quickserve.backend.security.JwtAuthFilter;
import com.quickserve.backend.security.UserDetailsServiceImpl;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
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
@Slf4j
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;
    private final UserDetailsServiceImpl userDetailsService;

    /**
     * Kapalı lab (IDE edge → VM cloud): JWT olmadan edge okuma/sync. ASLA internete açık ortamda true yapma.
     */
    @Value("${app.dev.insecure-edge-cloud-bridge:false}")
    private boolean insecureEdgeCloudBridge;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        if (insecureEdgeCloudBridge) {
            log.warn(
                    "SECURITY: app.dev.insecure-edge-cloud-bridge=true — /edge/bootstrap, /edge/sync, /waiter, /kitchen "
                            + "JWT olmadan herkese açık. Sadece güvenilir LAN / kapalı VM kullanın.");
        }
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(cors -> {}) // CorsConfig bean'ini kullan
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> {
                auth.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll();
                auth.requestMatchers("/customer/**").permitAll();
                auth.requestMatchers("/auth/**").permitAll();
                auth.requestMatchers(
                        "/swagger-ui/**",
                        "/api-docs/**",
                        "/actuator/health",
                        "/api/actuator/health"
                ).permitAll();
                auth.requestMatchers("/edge/enrollment/**").permitAll();
                if (insecureEdgeCloudBridge) {
                    auth.requestMatchers("/edge/bootstrap/**").permitAll();
                    auth.requestMatchers("/edge/sync/**").permitAll();
                    auth.requestMatchers("/waiter/**").permitAll();
                    auth.requestMatchers("/kitchen/**").permitAll();
                } else {
                    auth.requestMatchers("/edge/bootstrap/**").hasAnyRole(
                            "SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "WAITER", "CHEF", "VALET");
                    auth.requestMatchers("/edge/sync/**").hasAnyRole(
                            "SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "WAITER", "CHEF", "VALET");
                    auth.requestMatchers("/waiter/**").hasAnyRole(
                            "SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "WAITER");
                    auth.requestMatchers("/kitchen/**").hasAnyRole(
                            "SUPERADMIN", "RESTAURANT_ADMIN", "CHEF", "HEAD_WAITER");
                }
                auth.requestMatchers("/ws", "/ws/**").permitAll();
                auth.requestMatchers("/superadmin/**").hasRole("SUPERADMIN");
                auth.requestMatchers("/admin/**").hasAnyRole("SUPERADMIN", "RESTAURANT_ADMIN");
                auth.requestMatchers("/valet/**").hasAnyRole(
                        "SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "VALET");
                auth.anyRequest().authenticated();
            })
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
