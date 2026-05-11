package com.quickserve.backend.config;

import com.quickserve.backend.security.JwtAuthFilter;
import com.quickserve.backend.security.UserDetailsServiceImpl;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
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
@Slf4j
public class SecurityConfig {

    @Bean
    public EdgeCloudLabBridge edgeCloudLabBridge(
            Environment environment,
            @Value("${app.dev.insecure-edge-cloud-bridge:false}") boolean insecureEdgeCloudBridge) {
        EdgeCloudLabBridge bridge = new EdgeCloudLabBridge(environment, insecureEdgeCloudBridge);
        bridge.logStartupState();
        return bridge;
    }

    @Bean
    public SecurityFilterChain filterChain(
            HttpSecurity http,
            JwtAuthFilter jwtAuthFilter,
            UserDetailsServiceImpl userDetailsService,
            EdgeCloudLabBridge edgeCloudLabBridge,
            AuthenticationProvider authenticationProvider
    ) throws Exception {
        boolean insecureBridge = edgeCloudLabBridge.enabled();
        if (insecureBridge) {
            log.warn(
                    "SECURITY: app.dev.insecure-edge-cloud-bridge=true — /edge/bootstrap, /edge/sync, /edge/ops, "
                            + "/edge/nodes, /waiter, /kitchen JWT olmadan herkese açık. Sadece güvenilir LAN / kapalı VM kullanın.");
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
                    if (insecureBridge) {
                        auth.requestMatchers("/edge/bootstrap/**").permitAll();
                        auth.requestMatchers("/edge/sync/**").permitAll();
                        auth.requestMatchers("/edge/ops/**").permitAll();
                        auth.requestMatchers("/edge/nodes/**").permitAll();
                        auth.requestMatchers("/waiter/**").permitAll();
                        auth.requestMatchers("/kitchen/**").permitAll();
                    } else {
                        auth.requestMatchers("/edge/bootstrap/**").hasAnyRole(
                                "SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "WAITER", "CHEF", "VALET");
                        auth.requestMatchers("/edge/sync/**").hasAnyRole(
                                "SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "WAITER", "CHEF", "VALET");
                        auth.requestMatchers("/edge/ops/**").hasAnyRole(
                                "SUPERADMIN", "RESTAURANT_ADMIN", "HEAD_WAITER", "WAITER", "CHEF", "VALET");
                        auth.requestMatchers("/edge/nodes/**").hasAnyRole(
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
                .authenticationProvider(authenticationProvider)
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public AuthenticationProvider authenticationProvider(UserDetailsServiceImpl userDetailsService) {
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
