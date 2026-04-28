package com.quickserve.backend.dto.table;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class TableGroupResponse {
    private Long id;
    private String name;
    private Integer displayOrder;
    private Long tableCount;
}
