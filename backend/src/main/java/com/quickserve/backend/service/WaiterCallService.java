package com.quickserve.backend.service;

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
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class WaiterCallService {

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

        // Garsonlara bildir
        notificationService.notifyWaiters(session.getTable().getRestaurant().getId(),
                Map.of("callId", call.getId(), "tableNumber",
                        session.getTable().getTableNumber(), "type", type.name()));

        return call;
    }

    @Transactional
    public WaiterCall assignCall(Long callId, Long waiterId) {
        WaiterCall call = findById(callId);
        User waiter = userRepository.findById(waiterId)
                .orElseThrow(() -> new ResourceNotFoundException("User", waiterId));

        call.setAssignedTo(waiter);
        call.setStatus(WaiterCallStatus.IN_PROGRESS);
        call.setAssignedAt(LocalDateTime.now());
        return waiterCallRepository.save(call);
    }

    @Transactional
    public WaiterCall resolveCall(Long callId) {
        WaiterCall call = findById(callId);
        call.setStatus(WaiterCallStatus.RESOLVED);
        call.setResolvedAt(LocalDateTime.now());
        return waiterCallRepository.save(call);
    }

    @Transactional(readOnly = true)
    public List<WaiterCall> getPendingCalls(Long restaurantId) {
        return waiterCallRepository.findByRestaurantIdAndStatusIn(restaurantId,
                List.of(WaiterCallStatus.PENDING, WaiterCallStatus.IN_PROGRESS));
    }

    @Transactional(readOnly = true)
    public List<WaiterCall> getWaiterActiveCalls(Long waiterId) {
        return waiterCallRepository.findByAssignedToIdAndStatusNot(waiterId, WaiterCallStatus.RESOLVED);
    }

    public WaiterCall findById(Long id) {
        return waiterCallRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("WaiterCall", id));
    }
}
