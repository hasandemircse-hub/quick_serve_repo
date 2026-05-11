package com.quickserve.backend.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.core.env.Environment;

import java.util.Arrays;

/**
 * Kapalı lab: edge JWT olmadan /edge/bootstrap vb. — {@code prod} profilinde asla açılmaz.
 */
@Slf4j
public final class EdgeCloudLabBridge {

    private final Environment environment;
    private final boolean configured;

    public EdgeCloudLabBridge(Environment environment, boolean configured) {
        this.environment = environment;
        this.configured = configured;
    }

    public void logStartupState() {
        boolean prod = Arrays.stream(environment.getActiveProfiles()).anyMatch(p -> p.equalsIgnoreCase("prod"));
        if (prod && configured) {
            log.warn(
                    "app.dev.insecure-edge-cloud-bridge=true yok sayılıyor (aktif profil: prod). "
                            + "Edge lab için prod profilini kullanmayın.");
        }
        log.info(
                "Edge↔cloud lab bridge: enabled={}, propertyRaw={}, activeProfiles={}",
                enabled(),
                configured,
                Arrays.toString(environment.getActiveProfiles()));
    }

    public boolean enabled() {
        if (Arrays.stream(environment.getActiveProfiles()).anyMatch(p -> p.equalsIgnoreCase("prod"))) {
            return false;
        }
        return configured;
    }
}
