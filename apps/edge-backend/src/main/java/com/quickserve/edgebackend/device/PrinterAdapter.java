package com.quickserve.edgebackend.device;

public interface PrinterAdapter {
    String providerCode();

    PrintResult printReceipt(PrintReceiptRequest request);
}
