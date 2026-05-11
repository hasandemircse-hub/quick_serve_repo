-- Offline / senkron operasyonel cache + cloud ops cursor
CREATE TABLE IF NOT EXISTS edge_ops_meta (
    k TEXT PRIMARY KEY NOT NULL,
    v TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS edge_ops_order (
    order_id TEXT PRIMARY KEY NOT NULL,
    status TEXT NOT NULL,
    last_updated_at_utc TEXT NOT NULL,
    last_event_id TEXT,
    payload_json TEXT
);

CREATE TABLE IF NOT EXISTS edge_ops_call (
    call_id TEXT PRIMARY KEY NOT NULL,
    status TEXT,
    waiter_id TEXT,
    last_updated_at_utc TEXT NOT NULL,
    last_event_id TEXT,
    payload_json TEXT
);

CREATE TABLE IF NOT EXISTS edge_ops_payment (
    payment_id TEXT PRIMARY KEY NOT NULL,
    status TEXT,
    method TEXT,
    last_updated_at_utc TEXT NOT NULL,
    last_event_id TEXT,
    payload_json TEXT
);
