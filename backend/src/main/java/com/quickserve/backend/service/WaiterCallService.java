package com.quickserve.backend.service;

import com.quickserve.backend.dto.call.WaiterCallResponse;
import com.quickserve.backend.entity.*;
import com.quickserve.backend.enums.WaiterCallStatus;
import com.quickserve.backend.enums.WaiterCallType;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class WaiterCallService {

    private static final String CALLS_TOPIC = "calls";

    private final WaiterCallRepository waiterCallRepository;
    private final TableSessionRepository sessionRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    @Transactional
    public WaiterCall createCall(String sessionToken, WaiterCallType type, String notes) {
        TableSession session = sessionRepository.findBySessionToken(sessionToken)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));

        if (!session.getIsActive()) throw new BusinessException("Oturum aktif değil");

        WaiterCall call = WaiterCall.builder()
                .tableSession(session)
                .restaurant(session.getTable().getRestaurant())
                .type(type)
                .status(WaiterCallStatus.PENDING)
                .notes(notes)
                .build();
        call = waiterCallRepository.save(call);

        // Tüm garsonlara yeni çağrı bildirimi.
        notificationService.notifyWaiters(session.getTable().getRestaurant().getId(),
                buildPayload("CREATED", call));

        return call;
    }

    @Transactional
    public WaiterCall assignCall(Long callId, Long waiterId) {
        WaiterCall call = findById(callId);
        User waiter = userRepository.findById(waiterId)
                .orElseThrow(() -> new ResourceNotFoundException("User", waiterId));

        if (call.getStatus() != WaiterCallStatus.PENDING) {
            throw new BusinessException("Bu çağrı zaten alınmış");
        }

        call.setAssignedTo(waiter);
        call.setStatus(WaiterCallStatus.IN_PROGRESS);
        call.setAssignedAt(LocalDateTime.now());
        call = waiterCallRepository.save(call);

        Map<String, Object> payload = buildPayload("ASSIGNED", call);
        // Diğer garsonların listesi güncellensin.
        notificationService.publishToRestaurant(call.getRestaurant().getId(), CALLS_TOPIC, payload);
        // Müşteriye "garson geliyor" bildirimi.
        notificationService.publishToSession(
                call.getTableSession().getSessionToken(), CALLS_TOPIC, payload);

        return call;
    }

    @Transactional
    public WaiterCall resolveCall(Long callId) {
        WaiterCall call = findById(callId);
        call.setStatus(WaiterCallStatus.RESOLVED);
        call.setResolvedAt(LocalDateTime.now());
        call = waiterCallRepository.save(call);

        Map<String, Object> payload = buildPayload("RESOLVED", call);
        notificationService.publishToRestaurant(call.getRestaurant().getId(), CALLS_TOPIC, payload);
        notificationService.publishToSession(
                call.getTableSession().getSessionToken(), CALLS_TOPIC, payload);

        return call;
    }

    private Map<String, Object> buildPayload(String event, WaiterCall call) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("event", event);
        payload.put("callId", call.getId());
        payload.put("status", call.getStatus().name());
        payload.put("type", call.getType().name());
        payload.put("tableNumber", call.getTableSession().getTable().getTableNumber());
        User assigned = call.getAssignedTo();
        if (assigned != null) {
            String name = assigned.getFullName() != null && !assigned.getFullName().isBlank()
                    ? assigned.getFullName()
                    : assigned.getUsername();
            payload.put("assignedToName", name);
        }
        return payload;
    }

    @Transactional(readOnly = true)
    public List<WaiterCallResponse> getPendingCalls(Long restaurantId) {
        return waiterCallRepository.findByRestaurantIdAndStatusIn(restaurantId,
                List.of(WaiterCallStatus.PENDING, WaiterCallStatus.IN_PROGRESS))
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public List<WaiterCall> getWaiterActiveCalls(Long waiterId) {
        return waiterCallRepository.findByAssignedToIdAndStatusNot(waiterId, WaiterCallStatus.RESOLVED);
    }

    public WaiterCall findById(Long id) {
        return waiterCallRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("WaiterCall", id));
    }

    public WaiterCallResponse toDto(WaiterCall call) {
        User assigned = call.getAssignedTo();
        String assignedName = null;
        Long assignedId = null;
        if (assigned != null) {
            assignedName = assigned.getFullName() != null && !assigned.getFullName().isBlank()
                    ? assigned.getFullName()
                    : assigned.getUsername();
            assignedId = assigned.getId();
        }
        TableSession session = call.getTableSession();
        RestaurantTable table = session.getTable();
        return WaiterCallResponse.builder()
                .id(call.getId())
                .type(call.getType())
                .status(call.getStatus())
                .tableNumber(table.getTableNumber())
                .tableId(table.getId())
                .sessionId(session.getId())
                .notes(call.getNotes())
                .assignedToName(assignedName)
                .assignedToUserId(assignedId)
                .calledAt(call.getCalledAt())
                .assignedAt(call.getAssignedAt())
                .resolvedAt(call.getResolvedAt())
                .build();
    }
}
