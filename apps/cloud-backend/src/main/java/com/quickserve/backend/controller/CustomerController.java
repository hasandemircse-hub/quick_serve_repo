package com.quickserve.backend.controller;

import com.quickserve.backend.dto.edge.CustomerEdgeRouteResponse;
import com.quickserve.backend.dto.menu.MenuItemResponse;
import com.quickserve.backend.dto.order.OrderRequest;
import com.quickserve.backend.dto.order.OrderResponse;
import com.quickserve.backend.dto.payment.BillSplitRequest;
import com.quickserve.backend.dto.payment.PayableItemResponse;
import com.quickserve.backend.dto.payment.PaymentRequest;
import com.quickserve.backend.dto.payment.PaymentResponse;
import com.quickserve.backend.dto.payment.SessionFinancialSummaryResponse;
import com.quickserve.backend.dto.review.ReviewRequest;
import com.quickserve.backend.dto.review.ReviewResponse;
import com.quickserve.backend.dto.session.SessionResponse;
import com.quickserve.backend.enums.WaiterCallType;
import com.quickserve.backend.exception.BusinessException;
import com.quickserve.backend.service.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Müşteri ekranı endpointleri.
 * Kimlik doğrulama: X-Session-Token header (QR okutunca alınan token).
 */
@RestController
@RequestMapping("/customer")
@RequiredArgsConstructor
@Tag(name = "Customer", description = "Müşteri ekranı - QR token ile erişilir")
public class CustomerController {

    @Value("${app.customer-payment-simulation-enabled:false}")
    private boolean customerPaymentSimulationEnabled;

    private final TableService tableService;
    private final MenuService menuService;
    private final OrderService orderService;
    private final PaymentService paymentService;
    private final ReviewService reviewService;
    private final WaiterCallService waiterCallService;
    private final EdgeRoutingService edgeRoutingService;

    // ──── QR Okutma ──────────────────────────────────────────────────────────

    @GetMapping("/scan/{qrToken}")
    @Operation(summary = "QR kod okutma - restoran ve masa bilgisini döner, oturum açar")
    public ResponseEntity<SessionResponse> scanQr(@PathVariable String qrToken) {
        return ResponseEntity.ok(tableService.scanQr(qrToken));
    }

    @GetMapping("/session")
    @Operation(summary = "Aktif oturum bilgisi")
    public ResponseEntity<SessionResponse> getSession(
            @RequestHeader("X-Session-Token") String token) {
        return ResponseEntity.ok(tableService.getSessionByToken(token));
    }

    @GetMapping("/edge-route")
    @Operation(summary = "Müşteri için restoran edge route bilgisini çöz")
    public ResponseEntity<CustomerEdgeRouteResponse> getEdgeRoute(
            @RequestHeader("X-Session-Token") String token) {
        return ResponseEntity.ok(edgeRoutingService.resolveBySessionToken(token));
    }

    // ──── Menü ───────────────────────────────────────────────────────────────

    @GetMapping("/menu")
    @Operation(summary = "Menüyü kategorilere göre listele")
    public ResponseEntity<Map<String, List<MenuItemResponse>>> getMenu(
            @RequestHeader("X-Session-Token") String token) {
        SessionResponse session = tableService.getSessionByToken(token);
        return ResponseEntity.ok(menuService.getMenuGrouped(session.getRestaurantId()));
    }

    // ──── Sipariş ────────────────────────────────────────────────────────────

    @PostMapping("/orders")
    @Operation(summary = "Sipariş ver")
    public ResponseEntity<OrderResponse> createOrder(
            @RequestHeader("X-Session-Token") String token,
            @Valid @RequestBody OrderRequest request) {
        return ResponseEntity.ok(orderService.createOrder(token, request));
    }

    @GetMapping("/orders")
    @Operation(summary = "Oturumdaki geçmiş siparişleri listele")
    public ResponseEntity<List<OrderResponse>> getOrders(
            @RequestHeader("X-Session-Token") String token) {
        return ResponseEntity.ok(orderService.getSessionOrders(token));
    }

    // ──── Garson Çağırma ─────────────────────────────────────────────────────

    @PostMapping("/calls/waiter")
    @Operation(summary = "Garson çağır")
    public ResponseEntity<Void> callWaiter(
            @RequestHeader("X-Session-Token") String token,
            @RequestBody(required = false) Map<String, String> body) {
        String notes = body != null ? body.get("notes") : null;
        waiterCallService.createCall(token, WaiterCallType.CALL_WAITER, notes);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/calls/bill")
    @Operation(summary = "Hesap iste")
    public ResponseEntity<Void> requestBill(
            @RequestHeader("X-Session-Token") String token) {
        waiterCallService.createCall(token, WaiterCallType.REQUEST_BILL, null);
        return ResponseEntity.ok().build();
    }

    // ──── Ödeme ──────────────────────────────────────────────────────────────

    @GetMapping("/payments")
    @Operation(summary = "Oturumdaki ödemeleri listele")
    public ResponseEntity<List<PaymentResponse>> getPayments(
            @RequestHeader("X-Session-Token") String token) {
        return ResponseEntity.ok(paymentService.getSessionPayments(token));
    }

    @GetMapping("/payments/financial-summary")
    @Operation(summary = "Oturum finansal özeti")
    public ResponseEntity<SessionFinancialSummaryResponse> getFinancialSummary(
            @RequestHeader("X-Session-Token") String token) {
        return ResponseEntity.ok(paymentService.getSessionFinancialSummary(token));
    }

    @GetMapping("/payments/payable-items")
    @Operation(summary = "Ödenebilir sipariş kalemleri")
    public ResponseEntity<List<PayableItemResponse>> getPayableItems(
            @RequestHeader("X-Session-Token") String token) {
        return ResponseEntity.ok(paymentService.getSessionPayableItems(token));
    }

    @PostMapping("/payments/iyzico/init")
    @Operation(summary = "İyzico ödeme sayfası başlat (URL döner)")
    public ResponseEntity<Map<String, String>> initIyzicoPayment(
            @RequestHeader("X-Session-Token") String token,
            @Valid @RequestBody PaymentRequest request) {
        String url = paymentService.initIyzicoCheckout(token, request);
        return ResponseEntity.ok(Map.of("paymentUrl", url));
    }

    @PostMapping("/payments/simulate-complete")
    @Operation(summary = "[TEST] Ödemeyi tamamlanmış olarak kaydet (allocations). Sadece app.customer-payment-simulation-enabled=true")
    public ResponseEntity<PaymentResponse> simulatePaymentComplete(
            @RequestHeader("X-Session-Token") String token,
            @Valid @RequestBody PaymentRequest request) {
        if (!customerPaymentSimulationEnabled) {
            throw new BusinessException(
                    "Müşteri ödeme simülasyonu kapalı. Backend: app.customer-payment-simulation-enabled=true");
        }
        return ResponseEntity.ok(paymentService.simulateCustomerPayment(token, request));
    }

    @PostMapping("/payments/split")
    @Operation(summary = "Hesabı birden fazla kişiye böl")
    public ResponseEntity<Void> splitBill(
            @RequestHeader("X-Session-Token") String token,
            @Valid @RequestBody BillSplitRequest request) {
        paymentService.splitBill(token, request);
        return ResponseEntity.ok().build();
    }

    // ──── Değerlendirme ──────────────────────────────────────────────────────

    @PostMapping("/reviews")
    @Operation(summary = "Yorum ve oy ver")
    public ResponseEntity<ReviewResponse> createReview(
            @RequestHeader("X-Session-Token") String token,
            @Valid @RequestBody ReviewRequest request) {
        return ResponseEntity.ok(reviewService.createReview(token, request));
    }
}
