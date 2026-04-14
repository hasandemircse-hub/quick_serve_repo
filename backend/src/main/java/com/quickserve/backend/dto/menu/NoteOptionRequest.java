package com.quickserve.backend.dto.menu;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class NoteOptionRequest {
    @NotBlank
    private String text;
    private String textEn;
}
