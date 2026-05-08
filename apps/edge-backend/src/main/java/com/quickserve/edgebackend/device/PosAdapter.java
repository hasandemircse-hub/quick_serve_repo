package com.quickserve.edgebackend.device;

public interface PosAdapter {
    String providerCode();

    PosChargeResult charge(PosChargeRequest request);

    default boolean isHealthy() {
        return true;
    }
}
