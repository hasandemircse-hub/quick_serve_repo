package com.quickserve.edgebackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class EdgeBackendApplication {
    public static void main(String[] args) {
        SpringApplication.run(EdgeBackendApplication.class, args);
    }
}
