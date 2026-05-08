package com.quickserve.edgebackend.service;

import com.quickserve.edgebackend.device.PosAdapter;
import com.quickserve.edgebackend.device.PosChargeRequest;
import com.quickserve.edgebackend.device.PosChargeResult;
import com.quickserve.edgebackend.device.PosProviderException;
import com.quickserve.edgebackend.device.PrintReceiptRequest;
import com.quickserve.edgebackend.device.PrintResult;
import com.quickserve.edgebackend.device.PrinterAdapter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import static org.springframework.http.HttpStatus.BAD_REQUEST;
import static org.springframework.http.HttpStatus.CONFLICT;

@Service
public class DeviceAbstractionService {

    private static final Logger log = LoggerFactory.getLogger(DeviceAbstractionService.class);

    private final Map<String, PosAdapter> posAdapters;
    private final Map<String, PrinterAdapter> printerAdapters;
    private final EdgePosChargeAuditService posChargeAuditService;
    private final String defaultPosProvider;
    private final String defaultPrinterProvider;

    public DeviceAbstractionService(
            java.util.List<PosAdapter> posAdapters,
            java.util.List<PrinterAdapter> printerAdapters,
            EdgePosChargeAuditService posChargeAuditService,
            @Value("${app.edge.device.pos.default-provider:mock-pos}") String defaultPosProvider,
            @Value("${app.edge.device.printer.default-provider:mock-printer}") String defaultPrinterProvider
    ) {
        this.posAdapters = posAdapters.stream().collect(Collectors.toMap(PosAdapter::providerCode, Function.identity()));
        this.printerAdapters = printerAdapters.stream().collect(Collectors.toMap(PrinterAdapter::providerCode, Function.identity()));
        this.posChargeAuditService = posChargeAuditService;
        this.defaultPosProvider = defaultPosProvider;
        this.defaultPrinterProvider = defaultPrinterProvider;
    }

    public PosChargeResult charge(PosChargeRequest request, String providerCode) {
        String selectedProvider = normalize(providerCode, defaultPosProvider);
        PosAdapter adapter = posAdapters.get(selectedProvider);
        if (adapter == null) {
            throw new ResponseStatusException(BAD_REQUEST, "unknown_pos_provider: " + selectedProvider);
        }

        String idemKey = normalizeIdempotencyKey(request.idempotencyKey());
        String fingerprint = idemKey == null ? null : posChargeAuditService.fingerprint(selectedProvider, request);

        if (idemKey != null) {
            var existing = posChargeAuditService.find(idemKey, selectedProvider);
            if (existing.isPresent()) {
                var row = existing.get();
                if (!row.requestFingerprint().equals(fingerprint)) {
                    throw new ResponseStatusException(CONFLICT, "idempotency_key_conflict");
                }
                PosChargeResult replay = row.success()
                        ? PosChargeResult.success(selectedProvider, row.transactionId(), row.message())
                        : PosChargeResult.failure(
                                selectedProvider,
                                row.message() == null ? "pos_charge_failed" : row.message(),
                                row.errorCode() == null ? "provider_error" : row.errorCode(),
                                row.retryable());
                return replay.withIdempotentReplay();
            }
        }

        PosChargeResult result;
        try {
            result = adapter.charge(request);
        } catch (PosProviderException ex) {
            result = PosChargeResult.failure(
                    selectedProvider,
                    ex.getMessage(),
                    ex.errorCode(),
                    ex.retryable()
            );
        } catch (Exception ex) {
            Throwable root = rootCause(ex);
            boolean retryable = root instanceof SocketTimeoutException || root instanceof ConnectException;
            String errorCode = retryable ? "provider_unreachable" : "provider_error";
            log.warn("POS charge failed. provider={}, errorCode={}, message={}", selectedProvider, errorCode, ex.getMessage());
            result = PosChargeResult.failure(
                    selectedProvider,
                    ex.getMessage() == null ? "pos_charge_failed" : ex.getMessage(),
                    errorCode,
                    retryable
            );
        }

        if (idemKey != null) {
            posChargeAuditService.save(idemKey, selectedProvider, fingerprint, request, result, null);
        }
        return result;
    }

    public PrintResult printReceipt(PrintReceiptRequest request, String providerCode) {
        String selectedProvider = normalize(providerCode, defaultPrinterProvider);
        PrinterAdapter adapter = printerAdapters.get(selectedProvider);
        if (adapter == null) {
            throw new ResponseStatusException(BAD_REQUEST, "unknown_printer_provider: " + selectedProvider);
        }
        return adapter.printReceipt(request);
    }

    public Map<String, Object> adapterStatus() {
        return Map.of(
                "posProviders", posAdapters.keySet(),
                "posProviderHealth", posAdapters.entrySet().stream()
                        .collect(Collectors.toMap(Map.Entry::getKey, e -> e.getValue().isHealthy())),
                "printerProviders", printerAdapters.keySet(),
                "defaultPosProvider", defaultPosProvider,
                "defaultPrinterProvider", defaultPrinterProvider
        );
    }

    private Throwable rootCause(Throwable ex) {
        Throwable current = ex;
        while (current.getCause() != null) {
            current = current.getCause();
        }
        return current;
    }

    private String normalize(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    private String normalizeIdempotencyKey(String key) {
        if (key == null || key.isBlank()) {
            return null;
        }
        return key.trim();
    }
}
