import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../network/api_base_url_resolver.dart';
import '../network/websocket_service.dart';
import '../storage/local_storage.dart';

/// Authentication state provider
final authProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? role;
  final String? username;
  final int? restaurantId;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.role,
    this.username,
    this.restaurantId,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    String? role,
    String? username,
    int? restaurantId,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      role: role ?? this.role,
      username: username ?? this.username,
      restaurantId: restaurantId ?? this.restaurantId,
    );
  }
}

class AuthNotifier extends ChangeNotifier {
  AuthState _state = const AuthState();

  AuthState get state => _state;

  AuthNotifier() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await LocalStorage.getToken();
    if (token != null) {
      final userInfo = await LocalStorage.getUserInfo();
      _state = AuthState(
        isAuthenticated: true,
        token: token,
        role: userInfo['role'] as String?,
        username: userInfo['username'] as String?,
        restaurantId: userInfo['restaurantId'] as int?,
      );
      // Uygulama yeniden açıldığında yalnızca restoran-bağlı roller için WS aç.
      _syncWebSocketConnection();
      notifyListeners();
    }
  }

  Future<void> login(String token, Map<String, dynamic> userData) async {
    final restaurantId = userData['restaurantId'] is int
        ? userData['restaurantId'] as int
        : (userData['restaurantId'] is num
              ? (userData['restaurantId'] as num).toInt()
              : null);

    await LocalStorage.saveToken(token);
    await LocalStorage.saveUserInfo(
      username: userData['username'] ?? '',
      fullName: userData['fullName'],
      role: userData['role'] ?? '',
      restaurantName: userData['restaurantName'],
      restaurantId: restaurantId,
      isMenuImagesEnabled: userData['isMenuImagesEnabled'] == true,
      isPosDeviceEnabled: userData['isPosDeviceEnabled'] == true,
    );

    _state = AuthState(
      isAuthenticated: true,
      token: token,
      role: userData['role'],
      username: userData['username'],
      restaurantId: restaurantId,
    );

    _syncWebSocketConnection();
    notifyListeners();
  }

  Future<void> logout() async {
    WebSocketService.instance.disconnect();
    await LocalStorage.clearToken();
    await LocalStorage.clearUserInfo();
    _state = const AuthState();
    notifyListeners();
  }

  void _connectWebSocket(String token) {
    final role = _state.role ?? '';
    const staffRoles = <String>{
      'RESTAURANT_ADMIN',
      'HEAD_WAITER',
      'WAITER',
      'CHEF',
      'VALET',
    };
    final wsBaseUrl = staffRoles.contains(role)
        ? resolveApiBaseUrlWithOptions(
            ApiConstants.edgeBaseUrl,
            forceAbsolute: true,
          )
        : resolveApiBaseUrl(ApiConstants.cloudBaseUrl);

    WebSocketService.instance.connect(baseUrl: wsBaseUrl, jwtToken: token);
  }

  bool _shouldUseRealtime() {
    final role = _state.role;
    final restaurantId = _state.restaurantId;
    if (role == null || restaurantId == null) return false;
    const realtimeRoles = <String>{
      'RESTAURANT_ADMIN',
      'HEAD_WAITER',
      'WAITER',
      'CHEF',
      'VALET',
    };
    return realtimeRoles.contains(role);
  }

  void _syncWebSocketConnection() {
    final token = _state.token;
    if (token == null || !_shouldUseRealtime()) {
      WebSocketService.instance.disconnect();
      return;
    }
    _connectWebSocket(token);
  }

  bool hasRole(String requiredRole) {
    if (!_state.isAuthenticated || _state.role == null) return false;

    // Role hierarchy: SUPERADMIN > RESTAURANT_ADMIN > WAITER/HEAD_WAITER/CHEF
    final roleHierarchy = {
      'SUPERADMIN': 3,
      'RESTAURANT_ADMIN': 2,
      'HEAD_WAITER': 1,
      'WAITER': 1,
      'CHEF': 1,
      'VALET': 1,
    };

    final userLevel = roleHierarchy[_state.role] ?? 0;
    final requiredLevel = roleHierarchy[requiredRole] ?? 0;

    return userLevel >= requiredLevel;
  }
}
