package com.quickserve.backend.service;

import com.quickserve.backend.dto.session.SessionResponse;
import com.quickserve.backend.dto.table.TableLayoutUpdateRequest;
import com.quickserve.backend.dto.table.TableRequest;
import com.quickserve.backend.dto.table.TableResponse;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.entity.RestaurantTable;
import com.quickserve.backend.entity.TableGroup;
import com.quickserve.backend.entity.TableSession;
import com.quickserve.backend.enums.CloseReason;
import com.quickserve.backend.enums.TableStatus;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.RestaurantTableRepository;
import com.quickserve.backend.repository.TableGroupRepository;
import com.quickserve.backend.repository.TableSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TableService {

    private final RestaurantTableRepository tableRepository;
    private final TableGroupRepository tableGroupRepository;
    private final TableSessionRepository sessionRepository;
    private final RestaurantService restaurantService;
    private final QrCodeService qrCodeService;
    private final NotificationService notificationService;

    @Transactional
    public TableResponse createTable(Long restaurantId, TableRequest request) {
        if (tableRepository.existsByRestaurantIdAndTableNumber(restaurantId, request.getTableNumber())) {
            throw new BusinessException("Bu masa numarası zaten mevcut: " + request.getTableNumber());
        }
        Restaurant restaurant = restaurantService.findById(restaurantId);
        TableGroup group = resolveGroup(restaurantId, request.getTableGroupId());
        RestaurantTable table = RestaurantTable.builder()
                .restaurant(restaurant)
                .tableNumber(request.getTableNumber())
                .qrToken(UUID.randomUUID().toString())
                .status(TableStatus.EMPTY)
                .capacity(request.getCapacity() != null ? request.getCapacity() : 4)
                .zone(request.getZone())
                .tableGroup(group)
                .positionX(request.getPositionX() != null ? request.getPositionX() : 0)
                .positionY(request.getPositionY() != null ? request.getPositionY() : 0)
                .build();
        return toDto(tableRepository.save(table));
    }

    @Transactional
    public TableResponse updateTable(Long tableId, TableRequest request) {
        RestaurantTable table = findById(tableId);
        if (request.getTableNumber() != null) table.setTableNumber(request.getTableNumber());
        if (request.getCapacity() != null) table.setCapacity(request.getCapacity());
        if (request.getZone() != null) table.setZone(request.getZone());
        // tableGroupId açıkça gelirse uygulanır; null gönderilirse "Gruptan çıkar" anlamı taşır.
        // Bu yüzden alan request payload'unda mevcutsa setleriz; istemci dokunmuyorsa zaten gönderilmez.
        table.setTableGroup(resolveGroup(table.getRestaurant().getId(), request.getTableGroupId()));
        return toDto(tableRepository.save(table));
    }

    private TableGroup resolveGroup(Long restaurantId, Long groupId) {
        if (groupId == null) return null;
        TableGroup group = tableGroupRepository.findById(groupId)
                .orElseThrow(() -> new ResourceNotFoundException("TableGroup", groupId));
        if (!group.getRestaurant().getId().equals(restaurantId)) {
            throw new BusinessException("Masa grubu bu restorana ait değil");
        }
        return group;
    }

    @Transactional
    public void updateLayout(Long restaurantId, TableLayoutUpdateRequest request) {
        for (TableLayoutUpdateRequest.TablePosition pos : request.getPositions()) {
            tableRepository.findById(pos.getTableId()).ifPresent(t -> {
                if (t.getRestaurant().getId().equals(restaurantId)) {
                    t.setPositionX(pos.getPositionX());
                    t.setPositionY(pos.getPositionY());
                    tableRepository.save(t);
                }
            });
        }
    }

    @Transactional(readOnly = true)
    public List<TableResponse> getTables(Long restaurantId) {
        return tableRepository.findByRestaurantIdOrderByTableNumber(restaurantId)
                .stream().map(this::toDto).toList();
    }

    /**
     * QR okutulunca: varsa aktif oturumu döndür, yoksa yeni oturum aç.
     */
    @Transactional
    public SessionResponse scanQr(String qrToken) {
        RestaurantTable table = tableRepository.findByQrToken(qrToken)
                .orElseThrow(() -> new ResourceNotFoundException("QR kod geçersiz veya bulunamadı"));

        Restaurant restaurant = table.getRestaurant();

        if (!restaurant.isSubscriptionValid()) {
            throw new BusinessException("Bu restoran şu an aktif değil");
        }

        TableSession session = sessionRepository.findByTableIdAndIsActiveTrue(table.getId())
                .orElseGet(() -> createSession(table));

        // Masa doluysa oturum sayacını artır
        if (table.getStatus() == TableStatus.EMPTY) {
            table.setStatus(TableStatus.OCCUPIED);
            tableRepository.save(table);
            notificationService.publishToRestaurant(restaurant.getId(), "tables",
                    java.util.Map.of("tableId", table.getId(), "status", "OCCUPIED"));
        }

        return toSessionDto(session);
    }

    @Transactional
    public void closeSession(Long sessionId, Long closedByUserId, CloseReason reason) {
        TableSession session = sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("TableSession", sessionId));

        session.setIsActive(false);
        session.setClosedAt(LocalDateTime.now());
        session.setCloseReason(reason);
        sessionRepository.save(session);

        // Masayı boşalt
        RestaurantTable table = session.getTable();
        table.setStatus(TableStatus.EMPTY);
        tableRepository.save(table);

        notificationService.publishToRestaurant(table.getRestaurant().getId(), "tables",
                java.util.Map.of("tableId", table.getId(), "status", "EMPTY"));
        notificationService.publishToSession(session.getSessionToken(), "status",
                java.util.Map.of(
                        "event", "SESSION_CLOSED",
                        "sessionId", session.getId(),
                        "reason", reason.name(),
                        "message", "Masanız kapatıldı. Yeni işlem için lütfen QR kodu tekrar okutun."
                ));
    }

    @Transactional(readOnly = true)
    public SessionResponse getSessionByToken(String token) {
        TableSession session = sessionRepository.findBySessionToken(token)
                .orElseThrow(() -> new ResourceNotFoundException("Oturum bulunamadı"));
        return toSessionDto(session);
    }

    @Transactional
    public void regenerateQr(Long tableId) {
        RestaurantTable table = findById(tableId);
        // Yenileme öncesi mevcut token'ı "Geri Al" için sakla.
        table.setPreviousQrToken(table.getQrToken());
        table.setQrToken(UUID.randomUUID().toString());
        tableRepository.save(table);
    }

    /**
     * En son yenilenen QR'ı geri alır. previousQrToken yoksa hata.
     */
    @Transactional
    public void undoRegenerateQr(Long tableId) {
        RestaurantTable table = findById(tableId);
        String previous = table.getPreviousQrToken();
        if (previous == null || previous.isBlank()) {
            throw new BusinessException("Geri alınacak önceki QR yok");
        }
        // Çift undo'yu engellemek için previous'u boşaltıyoruz.
        table.setQrToken(previous);
        table.setPreviousQrToken(null);
        tableRepository.save(table);
    }

    public byte[] getQrImage(Long tableId) {
        RestaurantTable table = findById(tableId);
        return qrCodeService.generateQrBytes(table.getQrToken());
    }

    @Transactional
    public void deleteTable(Long tableId) {
        RestaurantTable table = findById(tableId);
        if (table.getStatus() == TableStatus.OCCUPIED) {
            throw new BusinessException("Dolu masalar silinemez");
        }
        tableRepository.delete(table);
    }

    private TableSession createSession(RestaurantTable table) {
        TableSession session = TableSession.builder()
                .table(table)
                .sessionToken(UUID.randomUUID().toString())
                .isActive(true)
                .guestCount(1)
                .build();
        return sessionRepository.save(session);
    }

    public RestaurantTable findById(Long id) {
        return tableRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Table", id));
    }

    public TableResponse toDto(RestaurantTable t) {
        TableSession activeSession = sessionRepository.findByTableIdAndIsActiveTrue(t.getId()).orElse(null);
        TableGroup group = t.getTableGroup();
        return TableResponse.builder()
                .id(t.getId())
                .tableNumber(t.getTableNumber())
                .status(t.getStatus())
                .positionX(t.getPositionX())
                .positionY(t.getPositionY())
                .capacity(t.getCapacity())
                .zone(t.getZone())
                .tableGroupId(group != null ? group.getId() : null)
                .tableGroupName(group != null ? group.getName() : null)
                .qrToken(t.getQrToken())
                .qrUrl(qrCodeService.generateQrUrl(t.getQrToken()))
                .hasPreviousQr(t.getPreviousQrToken() != null && !t.getPreviousQrToken().isBlank())
                .activeSessionId(activeSession != null ? activeSession.getId() : null)
                .build();
    }

    private SessionResponse toSessionDto(TableSession s) {
        Restaurant r = s.getTable().getRestaurant();
        return SessionResponse.builder()
                .sessionId(s.getId())
                .sessionToken(s.getSessionToken())
                .tableId(s.getTable().getId())
                .tableNumber(s.getTable().getTableNumber())
                .restaurantId(r.getId())
                .restaurantName(r.getName())
                .restaurantLogoUrl(r.getLogoUrl())
                .restaurantPrimaryColor(r.getPrimaryColor())
                .openedAt(s.getOpenedAt())
                .isActive(s.getIsActive())
                .build();
    }
}
