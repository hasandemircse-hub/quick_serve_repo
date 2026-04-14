package com.quickserve.backend.dto.restaurant;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class RestaurantRequest {
    @NotBlank
    private String name;
    private String phone;
    private String email;
    private String address;
    private String logoUrl;
    private String backgroundImageUrl;
    private String primaryColor;
    private String fontFamily;
    private String ibanNumber;
    private String iyzicoApiKey;
    private String iyzicoSecretKey;
    private String iyzicoBaseUrl;
}
