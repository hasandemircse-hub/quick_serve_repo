package com.quickserve.backend.dto.table;

import com.quickserve.backend.enums.TableStatus;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class TableResponse {
    private Long id;
    private String tableNumber;
    private TableStatus status;
    private Integer positionX;
    private Integer positionY;
    private Integer capacity;
    private String zone;
    private Long tableGroupId;
    private String tableGroupName;
    private String qrToken;
    private String qrUrl;          // Müşteri QR linki
    private Boolean hasPreviousQr; // Geri alınabilir önceki QR var mı
    private Long activeSessionId;  // Aktif oturum varsa
}
