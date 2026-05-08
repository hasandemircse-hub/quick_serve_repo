package com.quickserve.edgebackend.controller;

import com.quickserve.edgebackend.service.EdgeInboxProcessorService;
import com.quickserve.edgebackend.service.EdgeSyncOutboxService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/edge/sync")
public class EdgeSyncController {

    private final EdgeSyncOutboxService outboxService;
    private final EdgeInboxProcessorService inboxProcessorService;

    public EdgeSyncController(
            EdgeSyncOutboxService outboxService,
            EdgeInboxProcessorService inboxProcessorService
    ) {
        this.outboxService = outboxService;
        this.inboxProcessorService = inboxProcessorService;
    }

    @PostMapping("/outbox/test")
    public ResponseEntity<Map<String, Object>> enqueueTestEvent(@Valid @RequestBody OutboxTestRequest request) {
        String payload = request.payloadJson() == null || request.payloadJson().isBlank() ? "{}" : request.payloadJson();
        outboxService.enqueueEvent(request.aggregateType(), request.aggregateId(), request.eventType(), payload);
        return ResponseEntity.ok(Map.of("status", "queued"));
    }

    @PostMapping("/inbox")
    public ResponseEntity<Map<String, Object>> receiveInboxEvent(@Valid @RequestBody InboxEventRequest request) {
        EdgeInboxProcessorService.ProcessResult result = inboxProcessorService.process(
                request.sourceEventId(),
                request.sourceSystem(),
                request.payloadJson(),
                true
        );
        return ResponseEntity.ok(buildResponse(result));
    }

    private Map<String, Object> buildResponse(EdgeInboxProcessorService.ProcessResult result) {
        if (result.retryCount() == null) {
            return Map.of("status", result.status(), "sourceEventId", result.sourceEventId());
        }
        if (result.backoffSeconds() == null) {
            return Map.of(
                    "status", result.status(),
                    "sourceEventId", result.sourceEventId(),
                    "retryCount", result.retryCount()
            );
        }
        return Map.of(
                "status", result.status(),
                "sourceEventId", result.sourceEventId(),
                "retryCount", result.retryCount(),
                "backoffSeconds", result.backoffSeconds()
        );
    }

    public record OutboxTestRequest(
            @NotBlank String aggregateType,
            @NotBlank String aggregateId,
            @NotBlank String eventType,
            String payloadJson
    ) {}

    public record InboxEventRequest(
            @NotBlank String sourceEventId,
            @NotBlank String sourceSystem,
            @NotBlank String payloadJson
    ) {}
}
