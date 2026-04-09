package com.quickserve.backend.service;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.quickserve.backend.model.RestaurantTable;
import com.quickserve.backend.model.TableStatus;
import com.quickserve.backend.repository.TableRepository;

@Service
public class TableService {
    @Autowired
    private TableRepository tableRepository;

    public List<RestaurantTable> getAllTables() {
        return tableRepository.findAll();
    }

    public Optional<RestaurantTable> getTableById(Long id) {
        return tableRepository.findById(id);
    }

    public RestaurantTable createTable(RestaurantTable table) {
        return tableRepository.save(table);
    }

    public RestaurantTable updateTable(Long id, RestaurantTable tableDetails) {
        return tableRepository.findById(id).map(table -> {
            table.setTableNumber(tableDetails.getTableNumber());
            table.setCapacity(tableDetails.getCapacity());
            table.setStatus(tableDetails.getStatus());
            table.setQrCode(tableDetails.getQrCode());
            return tableRepository.save(table);
        }).orElseThrow(() -> new RuntimeException("Masa bulunamadı"));
    }

    public void deleteTable(Long id) {
        tableRepository.deleteById(id);
    }

    public List<RestaurantTable> getTablesByStatus(TableStatus status) {
        return tableRepository.findByStatus(status);
    }

    public List<RestaurantTable> getEmptyTables() {
        return tableRepository.findByStatus(TableStatus.EMPTY);
    }

    public List<RestaurantTable> getOccupiedTables() {
        return tableRepository.findByStatus(TableStatus.OCCUPIED);
    }

    public Optional<RestaurantTable> getTableByQrCode(String qrCode) {
        return tableRepository.findByQrCode(qrCode);
    }

    public void occupyTable(Long id) {
        tableRepository.findById(id).ifPresent(table -> {
            table.setStatus(TableStatus.OCCUPIED);
            tableRepository.save(table);
        });
    }

    public void emptyTable(Long id) {
        tableRepository.findById(id).ifPresent(table -> {
            table.setStatus(TableStatus.EMPTY);
            tableRepository.save(table);
        });
    }
}
