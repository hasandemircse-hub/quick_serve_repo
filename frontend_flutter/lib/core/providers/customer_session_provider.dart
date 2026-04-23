import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../network/websocket_service.dart';
import '../storage/local_storage.dart';

final customerSessionProvider =
    ChangeNotifierProvider<CustomerSessionNotifier>((ref) {
  return CustomerSessionNotifier();
});

class CustomerToastEvent {
  final String message;
  final String? status;

  const CustomerToastEvent({
    required this.message,
    required this.status,
  });
}

class CustomerSessionNotifier extends ChangeNotifier {
  String? _sessionToken;
  List<dynamic> _orders = const [];
  CustomerToastEvent? _lastToastEvent;
  Timer? _fallbackPollTimer;

  String? get sessionToken => _sessionToken;
  List<dynamic> get orders => _orders;
  CustomerToastEvent? get lastToastEvent => _lastToastEvent;

  Future<void> init() async {
    final stored = await LocalStorage.getSessionToken();
    if (stored == null || stored.isEmpty) return;
    await setSession(stored);
  }

  Future<void> setSession(String token) async {
    if (_sessionToken == token && _orders.isNotEmpty) return;

    _sessionToken = token;
    await _loadOrders();
    _connectAndSubscribe();
    _startFallbackPolling();
    notifyListeners();
  }

  void clearSession() {
    if (_sessionToken != null) {
      WebSocketService.instance.unsubscribe(_statusDestination(_sessionToken!));
    }
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
    _sessionToken = null;
    _orders = const [];
    _lastToastEvent = null;
    notifyListeners();
  }

  void consumeToast() {
    _lastToastEvent = null;
  }

  Future<void> refreshOrders() => _loadOrders();

  Future<void> _loadOrders() async {
    if (_sessionToken == null) return;
    try {
      final res = await ApiClient.instance
          .get(ApiConstants.customerOrders, sessionToken: _sessionToken);
      _orders = List<dynamic>.from(res.data as List? ?? const []);
      notifyListeners();
    } catch (_) {
      // Sessiz fallback: polling devam eder.
    }
  }

  void _connectAndSubscribe() {
    if (_sessionToken == null) return;
    WebSocketService.instance.connect(baseUrl: ApiConstants.baseUrl);
    WebSocketService.instance.subscribeSession(
      _sessionToken!,
      'status',
      _handleStatusEvent,
    );
  }

  void _startFallbackPolling() {
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadOrders(),
    );
  }

  String _statusDestination(String token) => '/topic/session/$token/status';

  void _handleStatusEvent(dynamic payload) {
    if (payload is! String) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;

      final incomingId = decoded['id'];
      if (incomingId == null) return;

      final idx = _orders.indexWhere((o) => o['id'] == incomingId);
      if (idx >= 0) {
        final updated = List<dynamic>.from(_orders);
        updated[idx] = decoded;
        _orders = updated;
      } else {
        _orders = [decoded, ..._orders];
      }

      final status = decoded['status'] as String?;
      _lastToastEvent = CustomerToastEvent(
        message: _toastMessage(status, incomingId),
        status: status,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[CUSTOMER-WS] status parse error: $e');
    }
  }

  String _toastMessage(String? status, dynamic orderId) => switch (status) {
        'DELIVERED' => 'Siparişiniz masanıza teslim edildi. Afiyet olsun! (#$orderId)',
        _ => 'Sipariş #$orderId durumu: ${_statusLabel(status)}',
      };

  String _statusLabel(String? status) => switch (status) {
        'PENDING' => 'Bekleniyor',
        'PREPARING' => 'Hazırlanıyor',
        'READY' => 'Hazır',
        'DELIVERED' => 'Teslim edildi',
        'CANCELLED' => 'İptal edildi',
        _ => 'Güncellendi',
      };

  @override
  void dispose() {
    _fallbackPollTimer?.cancel();
    if (_sessionToken != null) {
      WebSocketService.instance.unsubscribe(_statusDestination(_sessionToken!));
    }
    super.dispose();
  }
}
