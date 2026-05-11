-- Tam restoran görüntüsü (cloud bootstrap) — offline okuma için tek blob.
CREATE TABLE IF NOT EXISTS edge_snapshot_restaurant (
    restaurant_id INTEGER NOT NULL PRIMARY KEY,
    payload_json TEXT NOT NULL,
    schema_version INTEGER NOT NULL DEFAULT 1,
    synced_at TEXT NOT NULL
);

-- İleride parça parça senkron / ek veri tipleri için genişletilebilir gölge tablo.
-- entity_type: TABLE, MENU_ITEM, STAFF, CUSTOM_* ; entity_key: "{restaurantId}:{logicalId}"
CREATE TABLE IF NOT EXISTS edge_shadow_entity (
    entity_type TEXT NOT NULL,
    entity_key TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (entity_type, entity_key)
);

CREATE INDEX IF NOT EXISTS idx_edge_shadow_entity_type ON edge_shadow_entity (entity_type);
