import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../auth/auth_session_events.dart';
import 'api_base_url_resolver.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _cloudDio;
  late final Dio _edgeDio;

  ApiClient._() {
    final cloudBaseUrl = resolveApiBaseUrl(ApiConstants.cloudBaseUrl);
    final edgeBaseUrl = resolveApiBaseUrlWithOptions(
      ApiConstants.edgeBaseUrl,
      forceAbsolute: true,
    );

    _cloudDio = Dio(_baseOptions(cloudBaseUrl));
    _edgeDio = Dio(_baseOptions(edgeBaseUrl));

    _cloudDio.interceptors.add(_AuthInterceptor());
    _cloudDio.interceptors.add(_ErrorInterceptor());
    _edgeDio.interceptors.add(_AuthInterceptor());
    _edgeDio.interceptors.add(_ErrorInterceptor());

    // TODO(OFFLINE): Offline modda cache'den yanıt dönmek için
    // CacheInterceptor eklenecek (Hive tabanlı)
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _cloudDio;

  BaseOptions _baseOptions(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  );

  bool _isEdgePath(String path) {
    const edgePrefixes = <String>[
      '/edge',
      '/waiter',
      '/kitchen',
      '/admin',
      '/notifications',
    ];
    return edgePrefixes.any(path.startsWith);
  }

  Dio _resolveClient(String path, String? sessionToken) {
    // Customer session akışı cloud gateway üzerinden devam eder.
    if (sessionToken != null) return _cloudDio;
    return _isEdgePath(path) ? _edgeDio : _cloudDio;
  }

  // ─── Customer (session token ile) ───────────────────────────────────────

  Future<Response> get(
    String path, {
    Map<String, dynamic>? params,
    String? sessionToken,
  }) {
    return _resolveClient(path, sessionToken).get(
      path,
      queryParameters: params,
      options: Options(
        headers: sessionToken != null
            ? {'X-Session-Token': sessionToken}
            : null,
      ),
    );
  }

  Future<Response> post(String path, {dynamic data, String? sessionToken}) {
    return _resolveClient(path, sessionToken).post(
      path,
      data: data,
      options: Options(
        headers: sessionToken != null
            ? {'X-Session-Token': sessionToken}
            : null,
      ),
    );
  }

  Future<Response> postEdgeFirstWithCloudFallback(String path, {dynamic data}) async {
    try {
      return await _edgeDio.post(path, data: data);
    } on DioException catch (edgeError) {
      final statusCode = edgeError.response?.statusCode;
      // Edge erişimi yoksa veya kullanıcı edge'de bulunamazsa cloud'a düş.
      if (statusCode == null || statusCode == 401 || statusCode == 403 || statusCode == 404) {
        return _cloudDio.post(path, data: data);
      }
      rethrow;
    }
  }

  Future<Response> getBytes(String path, {Map<String, dynamic>? params}) {
    final client = _resolveClient(path, null);
    return client.get(
      path,
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<Response> put(String path, {dynamic data}) =>
      _resolveClient(path, null).put(path, data: data);
  Future<Response> delete(String path) =>
      _resolveClient(path, null).delete(path);
  Future<Response> patch(String path, {dynamic data}) =>
      _resolveClient(path, null).patch(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null && !options.headers.containsKey('X-Session-Token')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Sadece gerçek oturum düşmesi için logout tetikle:
    // - 401 => oturum/token geçersiz
    // - /auth/login çağrısında 401 normal olabilir (yanlış şifre), burada logout yok.
    if (statusCode == 401 && !path.contains('/auth/login')) {
      AuthSessionEvents.notifyUnauthorized();
    }

    // 403/410 gibi durumlarda otomatik logout yapmıyoruz.
    handler.next(err);
  }
}

/// Backend ErrorResponse.message'ını çekip kullanıcıya gösterilebilir hale getirir.
/// Backend `{ "message": "..." }` döndürür; bağlantı hataları için fallback metin verilir.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      final msg = (data['message'] as String).trim();
      if (msg.isNotEmpty) return msg;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Sunucuya ulaşılamadı';
    }
  }
  return error.toString();
}
