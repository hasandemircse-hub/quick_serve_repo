import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// WebSocket (STOMP/SockJS) servisi.
/// Gerçek zamanlı bildirimler: yeni sipariş, sipariş durumu, garson çağrıları.
///
/// Mimari:
/// - SockJS handshake HTTP(S) şeması ister; bu yüzden baseUrl http(s) olarak verilir.
/// - JWT WebSocket handshake'te custom header taşıyamaz, bu yüzden `?token=` query
///   parametresi olarak gönderilir. Backend JwtAuthFilter bunu da okuyor.
/// - Bağlantı koparsa 3 saniyelik reconnect ile otomatik toparlanır. Tüm abonelikler
///   `_pendingSubscriptions` üzerinden saklanır ve yeniden bağlandığında geri
///   uygulanır; böylece ekranlar bir kez subscribe() çağırınca "takılı" kalır.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._();
  WebSocketService._();
  static WebSocketService get instance => _instance;

  StompClient? _client;
  bool _connected = false;

  /// Abonelikler: destination -> callback. Reconnect sonrası otomatik resubscribe.
  final Map<String, void Function(dynamic)> _pendingSubscriptions = {};
  final Map<String, void Function()> _activeUnsubscribers = {};

  /// Bağlantı hazır olduğunda tetiklenecek callback'ler (connect race için).
  final List<VoidCallback> _onConnectedCallbacks = [];

  bool get isConnected => _connected;

  /// baseUrl formatı: `http://host:8080/api` gibi. İçeride `/ws` eklenir.
  void connect({required String baseUrl, String? jwtToken}) {
    if (_client != null && _connected) {
      debugPrint('[WS] Zaten bağlı');
      return;
    }

    // baseUrl: "http://localhost:8080/api" -> "http://localhost:8080/api/ws"
    // SockJS HTTP(S) şeması bekler, ws:// DEĞİL.
    final sockJsUrl = _buildSockJsUrl(baseUrl, jwtToken);
    debugPrint('[WS] Bağlanılıyor: $sockJsUrl');

    _client = StompClient(
      config: StompConfig.sockJS(
        url: sockJsUrl,
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onWebSocketError: (dynamic err) => debugPrint('[WS] WebSocket error: $err'),
        onStompError: (frame) => debugPrint('[WS] STOMP error: ${frame.body}'),
        reconnectDelay: const Duration(seconds: 3),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );
    _client!.activate();
  }

  String _buildSockJsUrl(String baseUrl, String? token) {
    // baseUrl sonunda "/api" yoksa bile direkt "/ws" eklemek yeterli.
    // Backend'de endpoint: /ws (context-path: /api). Ama Flutter tarafında
    // baseUrl zaten /api ile bitiyor, bu yüzden /api/ws doğru.
    final trimmed = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final url = '$trimmed/ws';
    if (token != null && token.isNotEmpty) {
      return '$url?token=${Uri.encodeQueryComponent(token)}';
    }
    return url;
  }

  void _onConnect(StompFrame frame) {
    _connected = true;
    debugPrint('[WS] Bağlantı kuruldu');

    // Reconnect sonrası tüm pending abonelikleri yeniden aktive et.
    _activeUnsubscribers.clear();
    _pendingSubscriptions.forEach((destination, callback) {
      _doSubscribe(destination, callback);
    });

    // connect sonrası bekleyen kullanıcıları uyandır.
    for (final cb in List<VoidCallback>.from(_onConnectedCallbacks)) {
      try {
        cb();
      } catch (e) {
        debugPrint('[WS] onConnected callback hata: $e');
      }
    }
  }

  void _onDisconnect(StompFrame? frame) {
    _connected = false;
    debugPrint('[WS] Bağlantı koptu');
  }

  void _doSubscribe(String destination, void Function(dynamic) onMessage) {
    final unsub = _client!.subscribe(
      destination: destination,
      callback: (frame) {
        if (frame.body != null) onMessage(frame.body);
      },
    );
    _activeUnsubscribers[destination] = unsub;
  }

  /// Hedefe abone ol. Bağlantı henüz kurulmadıysa pending'e yazılır, connect olunca
  /// otomatik uygulanır. Aynı destination için son callback geçerlidir.
  void subscribe(String destination, void Function(dynamic) onMessage) {
    _pendingSubscriptions[destination] = onMessage;
    if (_connected && _client != null) {
      // önce eskisini kapat (idempotent)
      _activeUnsubscribers.remove(destination)?.call();
      _doSubscribe(destination, onMessage);
    }
  }

  void unsubscribe(String destination) {
    _pendingSubscriptions.remove(destination);
    _activeUnsubscribers.remove(destination)?.call();
  }

  /// Restoran kanalına abone ol (sipariş, masa, çağrı olayları).
  void subscribeRestaurant(int restaurantId, String topic, void Function(dynamic) onMessage) {
    subscribe('/topic/restaurant/$restaurantId/$topic', onMessage);
  }

  /// Müşteri oturumuna abone ol (sipariş durumu).
  void subscribeSession(String sessionToken, String topic, void Function(dynamic) onMessage) {
    subscribe('/topic/session/$sessionToken/$topic', onMessage);
  }

  /// Kullanıcıya özel bildirimler.
  void subscribeUserNotifications(String username, void Function(dynamic) onMessage) {
    subscribe('/user/$username/notifications', onMessage);
  }

  /// Bağlantı hazır olunca bir kez çalışır; zaten bağlıysa hemen çalışır.
  void onConnected(VoidCallback cb) {
    if (_connected) {
      cb();
      return;
    }
    _onConnectedCallbacks.add(cb);
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _connected = false;
    _pendingSubscriptions.clear();
    _activeUnsubscribers.clear();
    _onConnectedCallbacks.clear();
  }
}
