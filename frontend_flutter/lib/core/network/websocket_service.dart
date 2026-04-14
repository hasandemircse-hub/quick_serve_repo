import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// WebSocket (STOMP) servisi.
/// Gerçek zamanlı bildirimler, sipariş durumu güncellemeleri, garson çağrıları.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._();
  WebSocketService._();
  static WebSocketService get instance => _instance;

  StompClient? _client;
  bool _connected = false;

  void connect({String? jwtToken, required String baseUrl}) {
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst('/api', '/api/ws/websocket');

    _client = StompClient(
      config: StompConfig.sockJS(
        url: wsUrl,
        onConnect: _onConnect,
        onDisconnect: (_) { _connected = false; },
        onStompError: (frame) => debugPrint('STOMP error: ${frame.body}'),
        webSocketConnectHeaders: jwtToken != null
            ? {'Authorization': 'Bearer $jwtToken'}
            : {},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _connected = true;
    debugPrint('WebSocket connected');
  }

  bool get isConnected => _connected;

  /// Restoran kanalına abone ol (sipariş, masa, çağrı olayları).
  void subscribeRestaurant(Long restaurantId, String topic, Function(dynamic) onMessage) {
    _client?.subscribe(
      destination: '/topic/restaurant/$restaurantId/$topic',
      callback: (frame) {
        if (frame.body != null) onMessage(frame.body);
      },
    );
  }

  /// Müşteri oturumuna abone ol (sipariş durumu).
  void subscribeSession(String sessionToken, String topic, Function(dynamic) onMessage) {
    _client?.subscribe(
      destination: '/topic/session/$sessionToken/$topic',
      callback: (frame) {
        if (frame.body != null) onMessage(frame.body);
      },
    );
  }

  /// Kullanıcıya özel bildirimler.
  void subscribeUserNotifications(String username, Function(dynamic) onMessage) {
    _client?.subscribe(
      destination: '/user/$username/notifications',
      callback: (frame) {
        if (frame.body != null) onMessage(frame.body);
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    _connected = false;
  }
}

// TODO(OFFLINE-SYNC): Çevrimdışı modda aynı ağdaki cihazlar arası senkronizasyon
// mekanizması belirsiz. Seçenekler:
// 1. mDNS (multicast_dns paketi) ile yerel sunucu keşfi
// 2. WebRTC data channel ile peer-to-peer
// 3. Basit HTTP polling aynı ağdaki cihaza karşı
// Netleştirme gerekiyor.

// Dart'ta Long yok, typedef kullanalım:
typedef Long = int;
