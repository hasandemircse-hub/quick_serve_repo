package com.quickserve.backend.service;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.quickserve.backend.model.MenuItem;
import com.quickserve.backend.repository.MenuItemRepository;

@Service
public class MenuItemService {
    @Autowired
    private MenuItemRepository menuItemRepository;

    public List<MenuItem> getAllMenuItems() {
        return menuItemRepository.findAll();
    }

    public List<MenuItem> getAvailableMenuItems() {
        return menuItemRepository.findByAvailableTrue();
    }

    public Optional<MenuItem> getMenuItemById(Long id) {
        return menuItemRepository.findById(id);
    }

    public MenuItem createMenuItem(MenuItem menuItem) {
        return menuItemRepository.save(menuItem);
    }

    public MenuItem updateMenuItem(Long id, MenuItem menuItemDetails) {
        return menuItemRepository.findById(id).map(menuItem -> {
            menuItem.setName(menuItemDetails.getName());
            menuItem.setDescription(menuItemDetails.getDescription());
            menuItem.setPrice(menuItemDetails.getPrice());
            menuItem.setAvailable(menuItemDetails.getAvailable());
            return menuItemRepository.save(menuItem);
        }).orElseThrow(() -> new RuntimeException("Menü öğesi bulunamadı"));
    }

    public void deleteMenuItem(Long id) {
        menuItemRepository.deleteById(id);
    }

    public List<MenuItem> searchMenuItems(String name) {
        return menuItemRepository.findByNameContainingIgnoreCase(name);
    }
}
