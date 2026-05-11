package com.quickserve.edgebackend.edge;

/**
 * Cloud {@code EdgeSyncEventFields} ile aynı JSON anahtarları.
 */
public final class EdgeSyncPayloadFields {
    public static final String EVENT_TIMESTAMP_UTC = "eventTimestampUtc";
    public static final String AGGREGATE_TYPE = "aggregateType";
    public static final String AGGREGATE_ID = "aggregateId";
    public static final String SOURCE_SYSTEM = "sourceSystem";
    public static final String SOURCE_SEQUENCE = "sourceSequence";

    private EdgeSyncPayloadFields() {}
}
