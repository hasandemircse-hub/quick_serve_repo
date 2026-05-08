package com.quickserve.edgebackend.device;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.UUID;

@Component
public class MockPosAdapter implements PosAdapter {
    @Override
    public String providerCode() {
        return "mock-pos";
    }

    @Override
    public PosChargeResult charge(PosChargeRequest request) {
        if (request.amount() == null || request.amount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new PosProviderException("invalid_amount", "Amount must be positive", false);
        }

        if (request.currency() == null || request.currency().isBlank()) {
            throw new PosProviderException("invalid_currency", "Currency is required", false);
        }

        return PosChargeResult.success(
                providerCode(),
                "tx-" + UUID.randomUUID(),
                "mock_pos_charge_ok"
        );
    }
}
