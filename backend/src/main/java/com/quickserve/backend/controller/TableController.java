package com.quickserve.backend.controller;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.quickserve.backend.model.RestaurantTable;
import com.quickserve.backend.model.TableStatus;
import com.quickserve.backend.service.QrCodeService;
import com.quickserve.backend.service.TableService;

@RestController
@RequestMapping("/api/tables")
@CrossOrigin(origins = "*")
public class TableController {
    @Autowired
    private TableService tableService;

    @Autowired
    private QrCodeService qrCodeService;

    @GetMapping
    public ResponseEntity<List<RestaurantTable>> getAllTables() {
        return ResponseEntity.ok(tableService.getAllTables());
    }

    @GetMapping("/{id}")
    public ResponseEntity<RestaurantTable> getTableById(@PathVariable Long id) {
        return tableService.getTableById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<RestaurantTable> createTable(@RequestBody RestaurantTable table) {
        return ResponseEntity.ok(tableService.createTable(table));
    }

    @PutMapping("/{id}")
    public ResponseEntity<RestaurantTable> updateTable(@PathVariable Long id, @RequestBody RestaurantTable tableDetails) {
        return ResponseEntity.ok(tableService.updateTable(id, tableDetails));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTable(@PathVariable Long id) {
        tableService.deleteTable(id);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/status/{status}")
    public ResponseEntity<List<RestaurantTable>> getTablesByStatus(@PathVariable TableStatus status) {
        return ResponseEntity.ok(tableService.getTablesByStatus(status));
    }

    @GetMapping("/empty")
    public ResponseEntity<List<RestaurantTable>> getEmptyTables() {
        return ResponseEntity.ok(tableService.getEmptyTables());
    }

    @GetMapping("/occupied")
    public ResponseEntity<List<RestaurantTable>> getOccupiedTables() {
        return ResponseEntity.ok(tableService.getOccupiedTables());
    }

    @GetMapping("/qr/{qrCode}")
    public ResponseEntity<RestaurantTable> getTableByQrCode(@PathVariable String qrCode) {
        return tableService.getTableByQrCode(qrCode)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/occupy")
    public ResponseEntity<Void> occupyTable(@PathVariable Long id) {
        tableService.occupyTable(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/empty")
    public ResponseEntity<Void> emptyTable(@PathVariable Long id) {
        tableService.emptyTable(id);
        return ResponseEntity.ok().build();
    }

    @GetMapping(value = "/{id}/qr-code", produces = MediaType.IMAGE_PNG_VALUE)
    public ResponseEntity<byte[]> getQrCode(@PathVariable Long id) {
        return tableService.getTableById(id)
                .map(table -> {
                    try {
                        byte[] qrImage = qrCodeService.generateQrCode(table.getQrCode(), 300, 300);
                        return ResponseEntity.ok()
                                .contentType(MediaType.IMAGE_PNG)
                                .body(qrImage);
                    } catch (Exception e) {
                        return ResponseEntity.internalServerError().<byte[]>build();
                    }
                })
                .orElse(ResponseEntity.notFound().build());
    }
}
