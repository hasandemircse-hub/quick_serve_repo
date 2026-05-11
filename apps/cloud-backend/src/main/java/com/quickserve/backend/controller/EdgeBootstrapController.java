package com.quickserve.backend.controller;

import com.quickserve.backend.dto.call.WaiterCallResponse;
import com.quickserve.backend.dto.menu.MenuItemResponse;
import com.quickserve.backend.dto.order.OrderResponse;
import com.quickserve.backend.dto.table.TableResponse;
import com.quickserve.backend.dto.user.UserResponse;
import com.quickserve.backend.entity.User;
import com.quickserve.backend.enums.OrderStatus;
import com.quickserve.backend.enums.UserRole;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.security.SecurityUtils;
import com.quickserve.backend.service.MenuService;
import com.quickserve.backend.service.OrderService;
import com.quickserve.backend.service.StaffService;
import com.quickserve.backend.service.TableService;
import com.quickserve.backend.service.WaiterCallService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Edge ilk kurulum / periyodik senkron için restoran verisi tek pakette.
 * Genişletme: yeni alanlar snapshot JSON'a eklenebilir; edge tarafı şema sürümü ile uyumlar.
 */
@RestController
@RequestMapping("/edge/bootstrap")
@RequiredArgsConstructor
@Tag(name = "Edge bootstrap", description = "Edge offline önbellek için anlık restoran görüntüsü")
public class EdgeBootstrapController {

    public static final int SNAPSHOT_SCHEMA_VERSION = 1;

    private final SecurityUtils securityUtils;
    private final TableService tableService;
    private final MenuService menuService;
    private final StaffService staffService;
    private final OrderService orderService;
    private final WaiterCallService waiterCallService;

    @GetMapping("/snapshot")
    @Operation(summary = "Restoran anlık görüntüsü (masa, menü, personel, siparişler, çağrılar)")
    public ResponseEntity<Map<String, Object>> snapshot(
            @RequestParam(required = false) Long restaurantId
    ) {
        User user = securityUtils.getCurrentUser();
        Long rid = resolveRestaurantId(user, restaurantId);

        List<TableResponse> tables = tableService.getTables(rid);
        Map<String, List<MenuItemResponse>> menu = menuService.getMenuGrouped(rid);
        List<UserResponse> staff = staffService.getStaff(rid);
        List<OrderResponse> kitchenOrders = orderService.getKitchenOrders(rid);
        List<OrderResponse> readyOrders = orderService.getRestaurantOrders(rid, OrderStatus.READY);
        List<WaiterCallResponse> pendingCalls = waiterCallService.getPendingCalls(rid);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("schemaVersion", SNAPSHOT_SCHEMA_VERSION);
        body.put("generatedAt", Instant.now().toString());
        body.put("restaurantId", rid);
        body.put("tables", tables);
        body.put("menu", menu);
        body.put("staff", staff);
        body.put("kitchenOrders", kitchenOrders);
        body.put("readyOrders", readyOrders);
        body.put("pendingCalls", pendingCalls);
        return ResponseEntity.ok(body);
    }

    private Long resolveRestaurantId(User user, Long restaurantIdParam) {
        if (user.getRole() == UserRole.SUPERADMIN) {
            if (restaurantIdParam == null) {
                throw new BusinessException("SUPERADMIN için restaurantId sorgu parametresi zorunlu");
            }
            return restaurantIdParam;
        }
        if (user.getRestaurant() == null) {
            throw new BusinessException("Restoran bağlantılı kullanıcı gerekli");
        }
        Long rid = user.getRestaurant().getId();
        if (restaurantIdParam != null && !restaurantIdParam.equals(rid)) {
            throw new BusinessException("Başka restoranın verisine erişilemez");
        }
        return rid;
    }
}
