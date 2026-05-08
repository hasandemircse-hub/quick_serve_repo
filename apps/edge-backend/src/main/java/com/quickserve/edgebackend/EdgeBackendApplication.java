package com.quickserve.edgebackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@SpringBootApplication
@EnableScheduling
public class EdgeBackendApplication {

    /** Must match default in application.properties for spring.datasource.url. */
    private static final String DEFAULT_SQLITE_RELATIVE_PATH = "./data/edge.db";

    public static void main(String[] args) {
        ensureSqliteParentDirectoryExists();
        SpringApplication.run(EdgeBackendApplication.class, args);
    }

    /**
     * SQLite JDBC does not create parent directories; Flyway runs before any ApplicationRunner.
     */
    static void ensureSqliteParentDirectoryExists() {
        String raw = System.getenv("EDGE_SQLITE_PATH");
        if (raw == null || raw.isBlank()) {
            raw = System.getProperty("EDGE_SQLITE_PATH");
        }
        if (raw == null || raw.isBlank()) {
            raw = DEFAULT_SQLITE_RELATIVE_PATH;
        }
        Path file = Paths.get(raw.trim()).toAbsolutePath().normalize();
        Path parent = file.getParent();
        if (parent != null) {
            try {
                Files.createDirectories(parent);
            } catch (Exception e) {
                throw new IllegalStateException("Cannot create SQLite parent directory: " + parent, e);
            }
        }
    }
}
