package com.quickserve.backend.dto.menu;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class NoteOptionResponse {
    private Long id;
    private String text;
    private String textEn;
}
