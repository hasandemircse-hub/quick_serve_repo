CREATE TABLE IF NOT EXISTS edge_pos_charge_audit (
    idempotency_key TEXT NOT NULL,
    provider TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    payment_id TEXT,
    order_id TEXT,
    amount_text TEXT NOT NULL,
    currency TEXT NOT NULL,
    success INTEGER NOT NULL,
    transaction_id TEXT,
    message TEXT,
    error_code TEXT,
    retryable INTEGER NOT NULL DEFAULT 0,
    raw_response_excerpt TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (idempotency_key, provider)
);

CREATE INDEX IF NOT EXISTS idx_edge_pos_charge_audit_created_at
    ON edge_pos_charge_audit(created_at);
