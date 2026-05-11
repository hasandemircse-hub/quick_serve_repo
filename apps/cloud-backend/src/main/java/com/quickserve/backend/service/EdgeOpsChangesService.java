package com.quickserve.backend.service;

import com.quickserve.backend.dto.edge.EdgeOpsChangeItemResponse;
import com.quickserve.backend.dto.edge.EdgeOpsChangesResponse;
import com.quickserve.backend.entity.EdgeSyncReceivedEvent;
import com.quickserve.backend.repository.EdgeSyncReceivedEventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EdgeOpsChangesService {

    private final EdgeSyncReceivedEventRepository receivedEventRepository;

    @Transactional(readOnly = true)
    public EdgeOpsChangesResponse listAppliedChanges(Long restaurantId, Long sinceId, int limit) {
        int cap = Math.min(Math.max(limit, 1), 500);
        long cursor = sinceId == null ? 0L : sinceId;
        List<EdgeSyncReceivedEvent> rows = receivedEventRepository
                .findByRestaurantIdAndAppliedIsTrueAndIdGreaterThanOrderByIdAsc(
                        restaurantId,
                        cursor,
                        PageRequest.of(0, cap)
                );
        List<EdgeOpsChangeItemResponse> items = rows.stream()
                .map(e -> EdgeOpsChangeItemResponse.builder()
                        .id(e.getId())
                        .eventId(e.getEventId())
                        .eventType(e.getEventType())
                        .aggregateType(e.getAggregateType())
                        .aggregateId(e.getAggregateId())
                        .eventTimestampUtc(e.getEventTimestampUtc())
                        .payloadJson(e.getPayloadJson())
                        .build())
                .toList();
        Long nextSince = items.isEmpty() ? cursor : items.get(items.size() - 1).id();
        return new EdgeOpsChangesResponse(items, nextSince);
    }
}
