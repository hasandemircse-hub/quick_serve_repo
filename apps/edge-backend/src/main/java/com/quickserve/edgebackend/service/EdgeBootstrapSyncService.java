package com.quickserve.edgebackend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.quickserve.edgebackend.repository.EdgeSnapshotRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Iterator;
import java.util.Map;

/**
 * Cloud'dan tam restoran görüntüsünü çeker, SQLite'ta tutar; offline okuma için temel.
 * Yeni veri tipleri: snapshot JSON'a alan ekle + burada veya ayrı işleyicide shadow doldur.
 */
@Service
public class EdgeBootstrapSyncService {

    private static final Logger log = LoggerFactory.getLogger(EdgeBootstrapSyncService.class);

    private final CloudBridgeService cloudBridgeService;
    private final EdgeSnapshotRepository snapshotRepository;
    private final ObjectMapper objectMapper;
    private final long configuredRestaurantId;

    public EdgeBootstrapSyncService(
            CloudBridgeService cloudBridgeService,
            EdgeSnapshotRepository snapshotRepository,
            ObjectMapper objectMapper,
            @Value("${app.edge.restaurant-id:0}") long configuredRestaurantId
    ) {
        this.cloudBridgeService = cloudBridgeService;
        this.snapshotRepository = snapshotRepository;
        this.objectMapper = objectMapper;
        this.configuredRestaurantId = configuredRestaurantId;
    }

    /**
     * Bridge JWT ve cloud erişimi varsa snapshot çek; aksi halde no-op.
     *
     * @return true if snapshot was refreshed
     */
    public boolean pullSnapshotFromCloud() {
        if (!cloudBridgeService.isBridgeConfigured()) {
            log.debug("Edge bootstrap skipped: bridge JWT not configured");
            return false;
        }
        if (configuredRestaurantId <= 0) {
            log.warn("Edge bootstrap skipped: app.edge.restaurant-id / EDGE_RESTAURANT_ID is not set");
            return false;
        }
        try {
            Map<String, Object> snapshot = cloudBridgeService.fetchBootstrapSnapshot(
                    configuredRestaurantId > 0 ? Long.valueOf(configuredRestaurantId) : null);
            int version = 1;
            Object sv = snapshot.get("schemaVersion");
            if (sv instanceof Number n) {
                version = n.intValue();
            }
            String json = objectMapper.writeValueAsString(snapshot);
            snapshotRepository.upsertFullSnapshot(configuredRestaurantId, version, json);
            indexShadowEntities(configuredRestaurantId, snapshot);
            log.info("Edge bootstrap snapshot stored for restaurantId={}, schemaVersion={}",
                    configuredRestaurantId, version);
            return true;
        } catch (Exception ex) {
            log.warn("Edge bootstrap pull failed: {}", ex.getMessage());
            return false;
        }
    }

    private void indexShadowEntities(long restaurantId, Map<String, Object> snapshot) {
        snapshotRepository.deleteShadowTypes("TABLE", "MENU_ITEM", "STAFF");
        try {
            JsonNode root = objectMapper.valueToTree(snapshot);
            prefixIndexTables(restaurantId, root.path("tables"));
            prefixIndexStaff(restaurantId, root.path("staff"));
            prefixIndexMenu(restaurantId, root.path("menu"));
        } catch (Exception ex) {
            log.warn("Edge shadow indexing skipped: {}", ex.getMessage());
        }
    }

    private void prefixIndexTables(long restaurantId, JsonNode tablesNode) {
        if (!tablesNode.isArray()) {
            return;
        }
        for (JsonNode row : tablesNode) {
            JsonNode id = row.get("id");
            if (id == null || !id.canConvertToLong()) {
                continue;
            }
            String key = restaurantId + ":" + id.asLong();
            snapshotRepository.upsertShadowEntity("TABLE", key, row.toString());
        }
    }

    private void prefixIndexStaff(long restaurantId, JsonNode staffNode) {
        if (!staffNode.isArray()) {
            return;
        }
        for (JsonNode row : staffNode) {
            JsonNode id = row.get("id");
            if (id == null || !id.canConvertToLong()) {
                continue;
            }
            String key = restaurantId + ":" + id.asLong();
            snapshotRepository.upsertShadowEntity("STAFF", key, row.toString());
        }
    }

    private void prefixIndexMenu(long restaurantId, JsonNode menuNode) {
        if (!menuNode.isObject()) {
            return;
        }
        Iterator<String> cats = menuNode.fieldNames();
        while (cats.hasNext()) {
            String category = cats.next();
            JsonNode items = menuNode.get(category);
            if (!items.isArray()) {
                continue;
            }
            for (JsonNode item : items) {
                JsonNode id = item.get("id");
                if (id == null || !id.canConvertToLong()) {
                    continue;
                }
                String key = restaurantId + ":" + id.asLong();
                snapshotRepository.upsertShadowEntity("MENU_ITEM", key, item.toString());
            }
        }
    }
}
