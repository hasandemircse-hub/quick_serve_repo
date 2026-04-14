package com.quickserve.backend.dto.table;

import lombok.Data;

import java.util.List;

@Data
public class TableLayoutUpdateRequest {
    private List<TablePosition> positions;

    @Data
    public static class TablePosition {
        private Long tableId;
        private Integer positionX;
        private Integer positionY;
    }
}
