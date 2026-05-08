package com.quickserve.edgebackend.device;

public record PrintReceiptRequest(
        String receiptId,
        String content
) {
}
