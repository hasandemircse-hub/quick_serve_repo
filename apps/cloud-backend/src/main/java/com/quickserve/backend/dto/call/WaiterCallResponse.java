package com.quickserve.backend.dto.call;

import com.quickserve.backend.enums.WaiterCallStatus;
import com.quickserve.backend.enums.WaiterCallType;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class WaiterCallResponse {
    private Long id;
    private WaiterCallType type;
    private WaiterCallStatus status;
    private String tableNumber;
    private Long tableId;
    private Long sessionId;
    private String notes;
    private String assignedToName;
    private Long assignedToUserId;
    private LocalDateTime calledAt;
    private LocalDateTime assignedAt;
    private LocalDateTime resolvedAt;
}
