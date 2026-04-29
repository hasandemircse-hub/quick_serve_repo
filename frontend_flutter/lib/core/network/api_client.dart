import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'api_base_url_resolver.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: resolveApiBaseUrl(ApiConstants.baseUrl),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_AuthInterceptor());
    _dio.interceptors.add(_ErrorInterceptor());

    // TODO(OFFLINE): Offline modda cache'den yanıt dönmek için
    // CacheInterceptor eklenecek (Hive tabanlı)
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  // ─── Customer (session token ile) ───────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? params, String? sessionToken}) {
    return _dio.get(path,
        queryParameters: params,
        options: Options(headers: sessionToken != null ? {'X-Session-Token': sessionToken} : null));
  }

  Future<Response> post(String path, {dynamic data, String? sessionToken}) {
    return _dio.post(path,
        data: data,
        options: Options(headers: sessionToken != null ? {'X-Session-Token': sessionToken} : null));
  }

  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);
  Future<Response> patch(String path, {dynamic data}) => _dio.patch(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
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
    if (err.response?.statusCode == 401) {
      // Token süresi dolmuş - login'e yönlendir
      // TODO: GoRouter ile /login'e yönlendir
    }
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
