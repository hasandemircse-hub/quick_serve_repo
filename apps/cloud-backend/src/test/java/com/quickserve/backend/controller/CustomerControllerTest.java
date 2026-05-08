package com.quickserve.backend.controller;

import com.quickserve.backend.config.SecurityConfig;
import com.quickserve.backend.dto.session.SessionResponse;
import com.quickserve.backend.security.JwtAuthFilter;
import com.quickserve.backend.security.JwtUtil;
import com.quickserve.backend.security.UserDetailsServiceImpl;
import com.quickserve.backend.service.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(CustomerController.class)
@Import({SecurityConfig.class, JwtAuthFilter.class})
class CustomerControllerTest {

    @Autowired MockMvc mockMvc;

    @MockitoBean TableService tableService;
    @MockitoBean MenuService menuService;
    @MockitoBean OrderService orderService;
    @MockitoBean PaymentService paymentService;
    @MockitoBean ReviewService reviewService;
    @MockitoBean WaiterCallService waiterCallService;
    @MockitoBean EdgeRoutingService edgeRoutingService;

    // JwtAuthFilter doğal çalışsın, JwtUtil mock'lansın (token validasyonunu kapatır)
    @MockitoBean JwtUtil jwtUtil;
    @MockitoBean UserDetailsServiceImpl userDetailsService;
    // BackendApplication.initSuperadmin bean'i UserRepository gerektirir
    @MockitoBean com.quickserve.backend.repository.UserRepository userRepository;

    @Test
    void scanQr_validToken_returns200() throws Exception {
        SessionResponse session = SessionResponse.builder()
                .sessionId(1L).sessionToken("sess-token").tableId(1L)
                .tableNumber("1").restaurantId(1L).restaurantName("Test").build();

        when(tableService.scanQr("valid-qr-token")).thenReturn(session);

        mockMvc.perform(get("/customer/scan/valid-qr-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tableNumber").value("1"));
    }
}
