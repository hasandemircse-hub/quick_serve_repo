package com.quickserve.edgebackend.config;

import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

@Configuration
public class EdgeSqliteConfig {

    @Bean
    ApplicationRunner sqlitePragmaInitializer(JdbcTemplate jdbcTemplate) {
        return args -> {
            jdbcTemplate.execute("PRAGMA journal_mode=WAL;");
            jdbcTemplate.execute("PRAGMA synchronous=NORMAL;");
            jdbcTemplate.execute("PRAGMA foreign_keys=ON;");
            jdbcTemplate.execute("PRAGMA busy_timeout=5000;");
        };
    }
}
