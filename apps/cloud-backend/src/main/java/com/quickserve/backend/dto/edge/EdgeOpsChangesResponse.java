package com.quickserve.backend.dto.edge;

import java.util.List;

public record EdgeOpsChangesResponse(
        List<EdgeOpsChangeItemResponse> events,
        /** Son dönen kaydın id'si; bir sonraki poll için since parametresi olarak kullanılır. */
        Long nextSince
) {}
