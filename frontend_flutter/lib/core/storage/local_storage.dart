import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yerel depolama yönetimi.
/// - SharedPreferences: JWT token, session token, dil tercihi
/// - Hive: Menü cache (offline erişim için 1 hafta)
///
/// TODO(OFFLINE-CACHE): Hangi verilerin offline cache'leneceği netleştirilmeli.
/// Şu an: menü verisi + aktif oturum bilgisi.
class LocalStorage {
  static const _jwtKey = 'jwt_token';
  static const _sessionTokenKey = 'session_token';
  static const _langKey = 'language';
  static const _menuBox = 'menu_cache';
  static const _sessionBox = 'session_cache';

  // Oturum açan kullanıcı bilgileri
  static const _userUsernameKey = 'user_username';
  static const _userFullNameKey = 'user_full_name';
  static const _userRoleKey = 'user_role';
  static const _restaurantNameKey = 'restaurant_name';
  static const _isImpersonatedKey = 'is_impersonated';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_menuBox);
    await Hive.openBox(_sessionBox);
  }

  // ─── JWT Token ──────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_jwtKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
  }

  // ─── Müşteri Session Token ──────────────────────────────────────────────

  static Future<void> saveSessionToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, token);
  }

  static Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionTokenKey);
  }

  static Future<void> clearSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
  }

  // ─── Menü Cache (Offline) ───────────────────────────────────────────────

  static Future<void> cacheMenu(int restaurantId, Map<String, dynamic> menuData) async {
    final box = Hive.box(_menuBox);
    await box.put('menu_$restaurantId', {
      'data': menuData,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  static Map<String, dynamic>? getCachedMenu(int restaurantId) {
    final box = Hive.box(_menuBox);
    final cached = box.get('menu_$restaurantId');
    if (cached == null) return null;

    final cachedAt = DateTime.parse(cached['cachedAt']);
    // 1 haftalık cache süresi
    if (DateTime.now().difference(cachedAt).inDays > 7) {
      box.delete('menu_$restaurantId');
      return null;
    }
    return Map<String, dynamic>.from(cached['data']);
  }

  // ─── Dil Tercihi ────────────────────────────────────────────────────────

  static Future<void> saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) ?? 'tr';
  }

  // ─── Kullanıcı Oturum Bilgisi ───────────────────────────────────────────

  static Future<void> saveUserInfo({
    required String username,
    String? fullName,
    required String role,
    String? restaurantName,
    bool isImpersonated = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userUsernameKey, username);
    if (fullName != null) await prefs.setString(_userFullNameKey, fullName);
    await prefs.setString(_userRoleKey, role);
    if (restaurantName != null) {
      await prefs.setString(_restaurantNameKey, restaurantName);
    } else {
      await prefs.remove(_restaurantNameKey);
    }
    await prefs.setBool(_isImpersonatedKey, isImpersonated);
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(_userUsernameKey) ?? '',
      'fullName': prefs.getString(_userFullNameKey),
      'role': prefs.getString(_userRoleKey) ?? '',
      'restaurantName': prefs.getString(_restaurantNameKey),
      'isImpersonated': prefs.getBool(_isImpersonatedKey) ?? false,
    };
  }

  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userUsernameKey);
    await prefs.remove(_userFullNameKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_restaurantNameKey);
    await prefs.remove(_isImpersonatedKey);
  }
}
