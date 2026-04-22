import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/auth_provider.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  int? _subscribedRestaurantId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Bağlantı hazır olunca /topic/restaurant/{id}/orders kanalına abone ol.
    // Abonelik WebSocketService içinde "pending" olarak saklanır; bağlantı gelince
    // otomatik aktive olur ve reconnect'te tekrar uygulanır.
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupWebSocket());
  }

  @override
  void dispose() {
    if (_subscribedRestaurantId != null) {
      WebSocketService.instance.unsubscribe(
        '/topic/restaurant/$_subscribedRestaurantId/orders',
      );
    }
    super.dispose();
  }

  void _setupWebSocket() {
    final restaurantId = ref.read(authProvider).state.restaurantId;
    if (restaurantId == null) {
      debugPrint('[KITCHEN] restaurantId null, WS abonesi kurulamadı');
      return;
    }
    _subscribedRestaurantId = restaurantId;
    WebSocketService.instance.subscribeRestaurant(
      restaurantId,
      'orders',
      _handleOrderEvent,
    );
    debugPrint('[KITCHEN] Abone olundu: /topic/restaurant/$restaurantId/orders');
  }

  void _handleOrderEvent(dynamic body) {
    if (!mounted) return;
    try {
      final Map<String, dynamic> order = body is String
          ? jsonDecode(body) as Map<String, dynamic>
          : (body as Map).cast<String, dynamic>();

      setState(() {
        final idx = _orders.indexWhere((o) => o['id'] == order['id']);
        final status = order['status'];
        // READY/DELIVERED/CANCELLED → mutfak listesinden çıkar.
        final terminal = status == 'READY' || status == 'DELIVERED' || status == 'CANCELLED';

        if (terminal) {
          if (idx != -1) _orders.removeAt(idx);
        } else if (idx != -1) {
          _orders[idx] = order;
        } else {
          _orders = [order, ..._orders];
          _notifyNewOrder(order);
        }
      });
    } catch (e) {
      debugPrint('[KITCHEN] WS mesajı parse edilemedi: $e');
    }
  }

  void _notifyNewOrder(Map<String, dynamic> order) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Yeni sipariş: Masa ${order['tableNumber'] ?? '?'}'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadOrders() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.kitchenOrders);
      if (!mounted) return;
      setState(() {
        _orders = List<dynamic>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orders.where((o) => o['status'] == 'PENDING').toList();
    final preparing = _orders.where((o) => o['status'] == 'PREPARING').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutfak'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          Badge(
            label: Text('${pending.length}'),
            child: const Icon(Icons.notification_important),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('Bekleyen sipariş yok', style: TextStyle(fontSize: 18)))
          : Row(
              children: [
                // Bekleyenler
                Expanded(
                  child: _OrderColumn(
                    title: 'Bekliyor (${pending.length})',
                    color: Colors.red.shade100,
                    orders: pending,
                    onAction: (orderId) => _startPreparing(orderId),
                    actionLabel: 'Hazırlamaya Başla',
                    actionColor: Colors.orange,
                  ),
                ),
                const VerticalDivider(width: 1),
                // Hazırlanıyor
                Expanded(
                  child: _OrderColumn(
                    title: 'Hazırlanıyor (${preparing.length})',
                    color: Colors.orange.shade100,
                    orders: preparing,
                    onAction: (orderId) => _markReady(orderId),
                    actionLabel: 'Hazır',
                    actionColor: Colors.green,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _startPreparing(dynamic orderId) async {
    await ApiClient.instance.post('/kitchen/orders/$orderId/start');
    // WS event gelecek, ama yine de anında tazeleme için bir refresh yapabiliriz.
  }

  Future<void> _markReady(dynamic orderId) async {
    await ApiClient.instance.post('/kitchen/orders/$orderId/ready');
  }
}

class _OrderColumn extends StatelessWidget {
  final String title;
  final Color color;
  final List<dynamic> orders;
  final void Function(dynamic) onAction;
  final String actionLabel;
  final Color actionColor;

  const _OrderColumn({
    required this.title, required this.color, required this.orders,
    required this.onAction, required this.actionLabel, required this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: color,
          child: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: orders.length,
            itemBuilder: (ctx, i) {
              final order = orders[i];
              final items = List<dynamic>.from(order['items'] ?? []);
              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Masa ${order['tableNumber']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('#${order['id']}',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const Divider(),
                      ...items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: actionColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('x${item['quantity']}',
                                  style: TextStyle(color: actionColor, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item['menuItemName'] ?? '')),
                          ],
                        ),
                      )),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: actionColor,
                              foregroundColor: Colors.white),
                          onPressed: () => onAction(order['id']),
                          child: Text(actionLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
