package com.quickserve.backend.edge;

/**
 * Edge → Cloud senkron payload JSON alanları (LWW + aggregate).
 */
public final class EdgeSyncEventFields {
    public static final String EVENT_TIMESTAMP_UTC = "eventTimestampUtc";
    public static final String AGGREGATE_TYPE = "aggregateType";
    public static final String AGGREGATE_ID = "aggregateId";
    public static final String SOURCE_SYSTEM = "sourceSystem";
    public static final String SOURCE_SEQUENCE = "sourceSequence";

    private EdgeSyncEventFields() {}
}
