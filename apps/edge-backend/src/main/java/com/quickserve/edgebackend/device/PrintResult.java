package com.quickserve.edgebackend.device;

public record PrintResult(
        boolean success,
        String provider,
        String jobId,
        String message
) {
}
