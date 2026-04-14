package com.quickserve.backend.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Entity
@Table(name = "menu_item_note_options")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MenuItemNoteOption {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "menu_item_id", nullable = false)
    private MenuItem menuItem;

    @NotBlank
    @Column(nullable = false, length = 200)
    private String text;

    @Column(name = "text_en", length = 200)
    private String textEn;
}
