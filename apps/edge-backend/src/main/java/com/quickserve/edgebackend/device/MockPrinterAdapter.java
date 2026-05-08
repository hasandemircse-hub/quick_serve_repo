package com.quickserve.edgebackend.device;

import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class MockPrinterAdapter implements PrinterAdapter {
    @Override
    public String providerCode() {
        return "mock-printer";
    }

    @Override
    public PrintResult printReceipt(PrintReceiptRequest request) {
        return new PrintResult(
                true,
                providerCode(),
                "print-" + UUID.randomUUID(),
                "mock_printer_ok"
        );
    }
}
