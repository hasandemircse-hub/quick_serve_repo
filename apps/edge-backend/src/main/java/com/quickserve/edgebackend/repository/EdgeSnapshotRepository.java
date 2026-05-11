package com.quickserve.edgebackend.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public class EdgeSnapshotRepository {

    private final JdbcTemplate jdbc;

    public EdgeSnapshotRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<String> findSnapshotPayload(long restaurantId) {
        var rows = jdbc.query(
                "SELECT payload_json FROM edge_snapshot_restaurant WHERE restaurant_id = ?",
                (rs, i) -> rs.getString(1),
                restaurantId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public void upsertFullSnapshot(long restaurantId, int schemaVersion, String payloadJson) {
        jdbc.update("""
                INSERT INTO edge_snapshot_restaurant (restaurant_id, payload_json, schema_version, synced_at)
                VALUES (?, ?, ?, datetime('now'))
                ON CONFLICT(restaurant_id) DO UPDATE SET
                    payload_json = excluded.payload_json,
                    schema_version = excluded.schema_version,
                    synced_at = excluded.synced_at
                """, restaurantId, payloadJson, schemaVersion);
    }

    public void deleteShadowTypes(String... entityTypes) {
        if (entityTypes.length == 0) {
            return;
        }
        String placeholders = String.join(",", java.util.Collections.nCopies(entityTypes.length, "?"));
        jdbc.update("DELETE FROM edge_shadow_entity WHERE entity_type IN (" + placeholders + ")",
                (Object[]) entityTypes);
    }

    public void upsertShadowEntity(String entityType, String entityKey, String payloadJson) {
        jdbc.update("""
                INSERT INTO edge_shadow_entity (entity_type, entity_key, payload_json, updated_at)
                VALUES (?, ?, ?, datetime('now'))
                ON CONFLICT(entity_type, entity_key) DO UPDATE SET
                    payload_json = excluded.payload_json,
                    updated_at = excluded.updated_at
                """, entityType, entityKey, payloadJson);
    }
}
