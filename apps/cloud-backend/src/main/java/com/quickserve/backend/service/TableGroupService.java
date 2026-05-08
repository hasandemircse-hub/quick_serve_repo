package com.quickserve.backend.service;

import com.quickserve.backend.dto.menu.ReorderRequest;
import com.quickserve.backend.dto.table.TableGroupRequest;
import com.quickserve.backend.dto.table.TableGroupResponse;
import com.quickserve.backend.entity.Restaurant;
import com.quickserve.backend.entity.TableGroup;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.exception.ResourceNotFoundException;
import com.quickserve.backend.repository.RestaurantTableRepository;
import com.quickserve.backend.repository.TableGroupRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class TableGroupService {

    private final TableGroupRepository tableGroupRepository;
    private final RestaurantTableRepository tableRepository;
    private final RestaurantService restaurantService;

    @Transactional(readOnly = true)
    public List<TableGroupResponse> getGroups(Long restaurantId) {
        List<TableGroup> groups = tableGroupRepository.findByRestaurantIdOrderByDisplayOrder(restaurantId);
        return groups.stream().map(this::toDto).toList();
    }

    @Transactional
    public TableGroupResponse createGroup(Long restaurantId, TableGroupRequest request) {
        if (tableGroupRepository.existsByRestaurantIdAndNameIgnoreCase(restaurantId, request.getName())) {
            throw new BusinessException("Bu isimde masa grubu zaten mevcut: " + request.getName());
        }
        Restaurant restaurant = restaurantService.findById(restaurantId);
        TableGroup group = TableGroup.builder()
                .restaurant(restaurant)
                .name(request.getName())
                .displayOrder(request.getDisplayOrder() != null ? request.getDisplayOrder() : 0)
                .build();
        return toDto(tableGroupRepository.save(group));
    }

    @Transactional
    public TableGroupResponse updateGroup(Long restaurantId, Long groupId, TableGroupRequest request) {
        TableGroup group = ownedGroup(restaurantId, groupId);
        group.setName(request.getName());
        if (request.getDisplayOrder() != null) group.setDisplayOrder(request.getDisplayOrder());
        return toDto(tableGroupRepository.save(group));
    }

    @Transactional
    public void deleteGroup(Long restaurantId, Long groupId) {
        TableGroup group = ownedGroup(restaurantId, groupId);
        // Bu gruba bağlı masalar varsa sadece ilişkilerini kopar; masalar silinmesin.
        tableRepository.findByRestaurantIdOrderByTableNumber(restaurantId).forEach(t -> {
            if (t.getTableGroup() != null && t.getTableGroup().getId().equals(groupId)) {
                t.setTableGroup(null);
                tableRepository.save(t);
            }
        });
        tableGroupRepository.delete(group);
    }

    @Transactional
    public void reorder(Long restaurantId, List<ReorderRequest> items) {
        for (ReorderRequest item : items) {
            tableGroupRepository.findById(item.getId()).ifPresent(g -> {
                if (g.getRestaurant().getId().equals(restaurantId)) {
                    g.setDisplayOrder(item.getDisplayOrder());
                    tableGroupRepository.save(g);
                }
            });
        }
    }

    private TableGroup ownedGroup(Long restaurantId, Long groupId) {
        TableGroup group = tableGroupRepository.findById(groupId)
                .orElseThrow(() -> new ResourceNotFoundException("TableGroup", groupId));
        if (!group.getRestaurant().getId().equals(restaurantId)) {
            throw new BusinessException("Masa grubu bu restorana ait değil");
        }
        return group;
    }

    private TableGroupResponse toDto(TableGroup g) {
        long count = tableRepository.findByRestaurantIdOrderByTableNumber(g.getRestaurant().getId())
                .stream()
                .filter(t -> t.getTableGroup() != null && t.getTableGroup().getId().equals(g.getId()))
                .count();
        return TableGroupResponse.builder()
                .id(g.getId())
                .name(g.getName())
                .displayOrder(g.getDisplayOrder())
                .tableCount(count)
                .build();
    }
}
