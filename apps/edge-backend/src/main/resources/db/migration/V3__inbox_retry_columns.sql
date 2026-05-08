ALTER TABLE edge_sync_inbox ADD COLUMN status TEXT NOT NULL DEFAULT 'PENDING';
ALTER TABLE edge_sync_inbox ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE edge_sync_inbox ADD COLUMN last_error TEXT;
ALTER TABLE edge_sync_inbox ADD COLUMN next_attempt_at TEXT;
ALTER TABLE edge_sync_inbox ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime('now'));

CREATE INDEX IF NOT EXISTS idx_edge_sync_inbox_status_next_attempt
    ON edge_sync_inbox(status, next_attempt_at);
