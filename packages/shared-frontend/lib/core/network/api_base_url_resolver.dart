import 'api_base_url_resolver_web.dart'
    if (dart.library.io) 'api_base_url_resolver_io.dart';

/// Web'de (tarayıcı HTTPS) API çağrılarını otomatik olarak mevcut domain üzerinden yapar.
/// Böylece `http://...` gibi insecure endpoint istekleri (Mixed Content) engellenmez.
String resolveApiBaseUrl(String baseUrl) => resolveApiBaseUrlImpl(baseUrl);

/// `forceAbsolute=true` ise web'de same-origin path'e düşürmeden mutlak URL korunur.
/// Edge LAN endpoint'leri için kullanılır.
String resolveApiBaseUrlWithOptions(
  String baseUrl, {
  bool forceAbsolute = false,
}) => resolveApiBaseUrlImpl(baseUrl, forceAbsolute: forceAbsolute);
