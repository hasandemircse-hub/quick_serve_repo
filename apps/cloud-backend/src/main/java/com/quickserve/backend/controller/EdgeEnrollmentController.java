package com.quickserve.backend.controller;

import com.quickserve.backend.dto.edge.EdgeEnrollmentClaimRequest;
import com.quickserve.backend.dto.edge.EdgeEnrollmentClaimResponse;
import com.quickserve.backend.service.EdgeEnrollmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/edge/enrollment")
@RequiredArgsConstructor
@Tag(name = "Edge Enrollment", description = "Edge cihazlarının manuel token ile cloud'a kaydı")
public class EdgeEnrollmentController {

    private final EdgeEnrollmentService edgeEnrollmentService;

    @Operation(summary = "Edge enrollment token claim et ve edge node oluştur")
    @PostMapping("/claim")
    public ResponseEntity<EdgeEnrollmentClaimResponse> claim(@Valid @RequestBody EdgeEnrollmentClaimRequest request) {
        return ResponseEntity.ok(edgeEnrollmentService.claimToken(request));
    }
}
