/// API taban adresleri: önce `--dart-define`, isteğe bağlı olarak edge uygulaması
/// `edge_frontend.env` ile [applyFromMap] üzerinden güncellenir.
class ApiRuntimeConfig {
  ApiRuntimeConfig._();

  static String? _apiOverride;
  static String? _cloudOverride;
  static String? _edgeOverride;
  static String? _webAdminOverride;

  static const String _compileApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080/api',
  );
  static const String _compileCloudUrl = String.fromEnvironment(
    'CLOUD_API_URL',
    defaultValue: '',
  );
  static const String _compileEdgeUrl = String.fromEnvironment(
    'EDGE_API_URL',
    defaultValue: 'http://localhost:8081/api',
  );
  static const String _compileWebAdmin = String.fromEnvironment(
    'WEB_ADMIN_URL',
    defaultValue: 'http://localhost:8080/auth/admin',
  );

  static String get effectiveBaseUrl => _apiOverride ?? _compileApiUrl;

  static String get effectiveCloudBaseUrl {
    if (_cloudOverride != null) return _cloudOverride!;
    if (_compileCloudUrl.isNotEmpty) return _compileCloudUrl;
    return effectiveBaseUrl;
  }

  static String get effectiveEdgeBaseUrl => _edgeOverride ?? _compileEdgeUrl;

  static String get effectiveWebAdminUrl =>
      _webAdminOverride ?? _compileWebAdmin;

  /// [map] içindeki anahtarlar boş değilse derleme zamanı değerinin üzerine yazar.
  static void applyFromMap(Map<String, String> map) {
    String? pick(String key) {
      final raw = map[key];
      if (raw == null) return null;
      final t = raw.trim();
      if (t.isEmpty || t.startsWith('#')) return null;
      return t;
    }

    _apiOverride = pick('API_URL');
    _cloudOverride = pick('CLOUD_API_URL');
    _edgeOverride = pick('EDGE_API_URL');
    _webAdminOverride = pick('WEB_ADMIN_URL');
  }

  static void clearOverrides() {
    _apiOverride = null;
    _cloudOverride = null;
    _edgeOverride = null;
    _webAdminOverride = null;
  }
}
