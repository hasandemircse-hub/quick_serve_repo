package com.quickserve.backend;

import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.security.crypto.password.PasswordEncoder;

@SpringBootApplication
@EnableCaching
@EnableScheduling
@Slf4j
public class BackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(BackendApplication.class, args);
    }

    /**
     * Superadmin yoksa oluştur.
     */
    @Bean
    CommandLineRunner initSuperadmin(UserRepository userRepository,
                                     PasswordEncoder passwordEncoder,
                                     @Value("${app.superadmin.username}") String username,
                                     @Value("${app.superadmin.password}") String password,
                                     @Value("${app.superadmin.email}") String email,
                                     @Value("${app.superadmin.phone}") String phone) {
        return args -> {
            if (!userRepository.existsByUsername(username)) {
                User superadmin = User.builder()
                        .username(username)
                        .passwordHash(passwordEncoder.encode(password))
                        .email(email)
                        .phone(phone)
                        .fullName("Superadmin")
                        .role(UserRole.SUPERADMIN)
                        .isActive(true)
                        .isOnLeave(false)
                        .build();
                userRepository.save(superadmin);
                log.info("Superadmin user created: {}", username);
            }
        };
    }
}
