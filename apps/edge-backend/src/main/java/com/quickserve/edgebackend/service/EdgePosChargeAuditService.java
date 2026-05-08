package com.quickserve.edgebackend.service;

import com.quickserve.edgebackend.device.PosChargeRequest;
import com.quickserve.edgebackend.device.PosChargeResult;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;

@Service
public class EdgePosChargeAuditService {

    private static final int MAX_MESSAGE_LEN = 2000;
    private static final int MAX_RAW_LEN = 4000;

    private final JdbcTemplate jdbcTemplate;

    public EdgePosChargeAuditService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public String fingerprint(String provider, PosChargeRequest request) {
        String amountText = request.amount() == null ? "" : request.amount().stripTrailingZeros().toPlainString();
        String raw = provider + "|"
                + nullToEmpty(request.paymentId()) + "|"
                + nullToEmpty(request.orderId()) + "|"
                + amountText + "|"
                + nullToEmpty(request.currency());
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(raw.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (Exception e) {
            throw new IllegalStateException("fingerprint_failed", e);
        }
    }

    public Optional<StoredPosCharge> find(String idempotencyKey, String provider) {
        List<StoredPosCharge> rows = jdbcTemplate.query("""
                        SELECT request_fingerprint, success, transaction_id, message, error_code, retryable
                        FROM edge_pos_charge_audit
                        WHERE idempotency_key=? AND provider=?
                        """,
                (rs, rowNum) -> new StoredPosCharge(
                        rs.getString("request_fingerprint"),
                        rs.getInt("success") == 1,
                        rs.getString("transaction_id"),
                        rs.getString("message"),
                        rs.getString("error_code"),
                        rs.getInt("retryable") == 1
                ),
                idempotencyKey,
                provider);
        return rows.stream().findFirst();
    }

    public void save(
            String idempotencyKey,
            String provider,
            String fingerprint,
            PosChargeRequest request,
            PosChargeResult result,
            String rawResponseExcerpt
    ) {
        String amountText = request.amount() == null ? "" : request.amount().stripTrailingZeros().toPlainString();
        jdbcTemplate.update("""
                        INSERT INTO edge_pos_charge_audit (
                            idempotency_key, provider, request_fingerprint,
                            payment_id, order_id, amount_text, currency,
                            success, transaction_id, message, error_code, retryable,
                            raw_response_excerpt, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                        ON CONFLICT(idempotency_key, provider) DO UPDATE SET
                            request_fingerprint=excluded.request_fingerprint,
                            payment_id=excluded.payment_id,
                            order_id=excluded.order_id,
                            amount_text=excluded.amount_text,
                            currency=excluded.currency,
                            success=excluded.success,
                            transaction_id=excluded.transaction_id,
                            message=excluded.message,
                            error_code=excluded.error_code,
                            retryable=excluded.retryable,
                            raw_response_excerpt=excluded.raw_response_excerpt,
                            updated_at=datetime('now')
                        """,
                idempotencyKey,
                provider,
                fingerprint,
                request.paymentId(),
                request.orderId(),
                amountText,
                request.currency(),
                result.success() ? 1 : 0,
                result.transactionId(),
                truncate(result.message(), MAX_MESSAGE_LEN),
                result.errorCode(),
                result.retryable() ? 1 : 0,
                truncate(rawResponseExcerpt, MAX_RAW_LEN));
    }

    public int purgeOlderThanDays(int days) {
        if (days <= 0) {
            return 0;
        }
        return jdbcTemplate.update("""
                        DELETE FROM edge_pos_charge_audit
                        WHERE created_at <= datetime('now', printf('-%d days', ?))
                        """,
                days);
    }

    private static String nullToEmpty(String s) {
        return s == null ? "" : s.trim();
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return null;
        }
        if (s.length() <= max) {
            return s;
        }
        return s.substring(0, max);
    }

    public record StoredPosCharge(
            String requestFingerprint,
            boolean success,
            String transactionId,
            String message,
            String errorCode,
            boolean retryable
    ) {}
}
