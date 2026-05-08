package com.quickserve.edgebackend.controller;

import com.quickserve.edgebackend.device.PosChargeRequest;
import com.quickserve.edgebackend.device.PosChargeResult;
import com.quickserve.edgebackend.device.PrintReceiptRequest;
import com.quickserve.edgebackend.device.PrintResult;
import com.quickserve.edgebackend.service.DeviceAbstractionService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/device")
public class EdgeDeviceController {

    private final DeviceAbstractionService deviceAbstractionService;

    public EdgeDeviceController(DeviceAbstractionService deviceAbstractionService) {
        this.deviceAbstractionService = deviceAbstractionService;
    }

    @GetMapping("/providers")
    public ResponseEntity<Map<String, Object>> getProviders() {
        return ResponseEntity.ok(deviceAbstractionService.adapterStatus());
    }

    @PostMapping("/pos/charge")
    public ResponseEntity<PosChargeResult> charge(@Valid @RequestBody PosChargeApiRequest request) {
        PosChargeResult result = deviceAbstractionService.charge(
                new PosChargeRequest(
                        request.paymentId(),
                        request.amount(),
                        request.currency(),
                        request.orderId(),
                        request.idempotencyKey()
                ),
                request.provider()
        );
        return ResponseEntity.ok(result);
    }

    @PostMapping("/printer/receipt")
    public ResponseEntity<PrintResult> print(@Valid @RequestBody PrintReceiptApiRequest request) {
        PrintResult result = deviceAbstractionService.printReceipt(
                new PrintReceiptRequest(
                        request.receiptId() == null || request.receiptId().isBlank()
                                ? UUID.randomUUID().toString()
                                : request.receiptId(),
                        request.content()
                ),
                request.provider()
        );
        return ResponseEntity.ok(result);
    }

    public record PosChargeApiRequest(
            String provider,
            String paymentId,
            @NotNull @DecimalMin(value = "0.01") BigDecimal amount,
            @NotBlank String currency,
            @NotBlank String orderId,
            @Size(max = 128) String idempotencyKey
    ) {}

    public record PrintReceiptApiRequest(
            String provider,
            String receiptId,
            @NotBlank String content
    ) {}
}
