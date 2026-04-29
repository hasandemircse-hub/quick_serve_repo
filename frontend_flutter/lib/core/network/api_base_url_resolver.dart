import 'api_base_url_resolver_web.dart'
    if (dart.library.io) 'api_base_url_resolver_io.dart';

/// Web'de (tarayıcı HTTPS) API çağrılarını otomatik olarak mevcut domain üzerinden yapar.
/// Böylece `http://...` gibi insecure endpoint istekleri (Mixed Content) engellenmez.
String resolveApiBaseUrl(String baseUrl) => resolveApiBaseUrlImpl(baseUrl);

