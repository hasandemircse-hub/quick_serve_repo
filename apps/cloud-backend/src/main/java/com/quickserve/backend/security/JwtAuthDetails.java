package com.quickserve.backend.security;

/**
 * JWT'den çıkarılan ek bilgileri Authentication#details alanında taşır.
 * İmpersonation durumunda restaurantId, JWT'deki claim'den gelir
 * (kullanıcının entity'sindeki restaurant null olabilir).
 */
public record JwtAuthDetails(Long restaurantId, boolean impersonated) {}
