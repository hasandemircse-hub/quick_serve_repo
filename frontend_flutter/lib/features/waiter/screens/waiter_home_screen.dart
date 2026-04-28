import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/network/websocket_service.dart';

class WaiterHomeScreen extends ConsumerStatefulWidget {
  const WaiterHomeScreen({super.key});

  @override
  ConsumerState<WaiterHomeScreen> createState() => _WaiterHomeScreenState();
}

class _WaiterHomeScreenState extends ConsumerState<WaiterHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _tables = [];
  List<dynamic> _calls = [];
  List<dynamic> _readyOrders = [];
  bool _loading = true;
  int? _restaurantId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRealtime();
    });
  }

  void _initRealtime() {
    final id = ref.read(authProvider).state.restaurantId;
    if (id == null) return;
    _restaurantId = id;
    WebSocketService.instance.subscribeRestaurant(
      id,
      'orders',
      _handleOrderEvent,
    );
    WebSocketService.instance.subscribeRestaurant(
      id,
      'calls',
      _handleCallEvent,
    );
  }

  void _handleCallEvent(dynamic payload) {
    if (!mounted) return;
    // Hangi event olursa olsun listeyi tazelemek en güvenli yol —
    // backend, çağrıyı başka bir garson üstlenince ASSIGNED yayınlar,
    // bu durumda diğer garsonların listesindeki "Üstlen" butonu güncellenmeli.
    _loadData();

    if (payload is! String) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final event = decoded['event'];
      final tableNumber = decoded['tableNumber']?.toString() ?? '?';
      if (event == 'CREATED') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yeni çağrı: Masa $tableNumber'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (event == 'ASSIGNED') {
        final name = decoded['assignedToName'] as String?;
        if (name != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Masa $tableNumber çağrısını $name üstlendi'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {/* sessiz */}
  }

  void _handleOrderEvent(dynamic payload) {
    if (!mounted || payload is! String) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;

      final orderId = decoded['id'];
      final status = decoded['status'] as String?;
      if (orderId == null || status == null) return;

      setState(() {
        final current = List<dynamic>.from(_readyOrders);
        final idx = current.indexWhere((o) => o['id'] == orderId);

        if (status == 'READY') {
          if (idx >= 0) {
            current[idx] = decoded;
          } else {
            current.insert(0, decoded);
          }
        } else {
          if (idx >= 0) {
            current.removeAt(idx);
          }
        }
        _readyOrders = current;
      });

      if (status == 'READY') {
        final tableNumber = decoded['tableNumber']?.toString() ?? '?';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masa $tableNumber siparişi hazır: #$orderId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      // parse hatalarında sessiz geç
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiClient.instance.get(ApiConstants.waiterTables),
        ApiClient.instance.get(ApiConstants.waiterCalls),
        ApiClient.instance.get(ApiConstants.waiterOrders),
      ]);
      setState(() {
        _tables = List<dynamic>.from(results[0].data);
        _calls = List<dynamic>.from(results[1].data);
        _readyOrders = List<dynamic>.from(results[2].data);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCallCount = _calls.length;
    final readyCount = _readyOrders.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garson Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Kasa',
            onPressed: () => context.go('/cashier'),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.table_restaurant), text: 'Masalar'),
            Tab(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Tab(icon: Icon(Icons.support_agent), text: 'Çağrılar'),
                  if (pendingCallCount > 0)
                    Positioned(
                      right: -8, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('$pendingCallCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Tab(icon: Icon(Icons.delivery_dining), text: 'Siparişler'),
                  if (readyCount > 0)
                    Positioned(
                      right: -8, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        child: Text('$readyCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _TablesTab(tables: _tables, onRefresh: _loadData),
                _CallsTab(calls: _calls, onRefresh: _loadData),
                _OrdersTab(orders: _readyOrders, onRefresh: _loadData),
              ],
            ),
    );
  }

  @override
  void dispose() {
    final id = _restaurantId;
    if (id != null) {
      WebSocketService.instance.unsubscribe('/topic/restaurant/$id/orders');
      WebSocketService.instance.unsubscribe('/topic/restaurant/$id/calls');
    }
    _tabController.dispose();
    super.dispose();
  }
}

class _TablesTab extends StatelessWidget {
  final List<dynamic> tables;
  final VoidCallback onRefresh;
  const _TablesTab({required this.tables, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.2, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: tables.length,
      itemBuilder: (ctx, i) {
        final table = tables[i];
        final isOccupied = table['status'] == 'OCCUPIED';
        return Card(
          color: isOccupied ? Colors.orange.shade100 : Colors.green.shade100,
          child: InkWell(
            onTap: isOccupied ? () => _showTableActions(context, table) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.table_restaurant,
                    color: isOccupied ? Colors.orange : Colors.green, size: 32),
                Text('Masa ${table['tableNumber']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(isOccupied ? 'Dolu' : 'Boş',
                    style: TextStyle(color: isOccupied ? Colors.orange : Colors.green,
                        fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTableActions(BuildContext context, Map<String, dynamic> table) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Hesap Ödenerek Kalkıldı'),
            onTap: () {
              Navigator.pop(ctx);
              _closeSession(context, table['activeSessionId'], 'PAID_BILL');
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.orange),
            title: const Text('İşlemsiz Kalkıldı'),
            onTap: () {
              Navigator.pop(ctx);
              _closeSession(context, table['activeSessionId'], 'NO_BILL');
            },
          ),
          ListTile(
            leading: const Icon(Icons.more_horiz),
            title: const Text('Diğer'),
            onTap: () {
              Navigator.pop(ctx);
              _closeSession(context, table['activeSessionId'], 'OTHER');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _closeSession(BuildContext context, dynamic sessionId, String reason) async {
    try {
      await ApiClient.instance.post('/waiter/sessions/$sessionId/close',
          data: {'reason': reason});
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }
}

class _CallsTab extends StatelessWidget {
  final List<dynamic> calls;
  final VoidCallback onRefresh;
  const _CallsTab({required this.calls, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) {
      return const Center(child: Text('Bekleyen çağrı yok'));
    }
    return ListView.builder(
      itemCount: calls.length,
      itemBuilder: (ctx, i) {
        final call = calls[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              call['type'] == 'REQUEST_BILL' ? Icons.receipt : Icons.support_agent,
              color: Colors.red,
            ),
            title: Text('Masa ${call['tableNumber'] ?? '?'}'),
            subtitle: Text(
              call['assignedToName'] != null
                  ? '${_callTypeLabel(call['type'])} · ${call['assignedToName']} üstlendi'
                  : _callTypeLabel(call['type']),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (call['status'] == 'PENDING')
                  TextButton(
                    onPressed: () => _assignCall(context, call['id']),
                    child: const Text('Üstlen'),
                  ),
                if (call['status'] == 'IN_PROGRESS')
                  TextButton(
                    onPressed: () => _resolveCall(context, call['id']),
                    child: const Text('Çözüldü'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _callTypeLabel(String? type) {
    return switch (type) {
      'CALL_WAITER' => 'Garson çağrısı',
      'REQUEST_BILL' => 'Hesap isteniyor',
      _ => 'Diğer talep',
    };
  }

  Future<void> _assignCall(BuildContext context, dynamic callId) async {
    await ApiClient.instance.post('/waiter/calls/$callId/assign');
    onRefresh();
  }

  Future<void> _resolveCall(BuildContext context, dynamic callId) async {
    await ApiClient.instance.post('/waiter/calls/$callId/resolve');
    onRefresh();
  }
}

class _OrdersTab extends StatelessWidget {
  final List<dynamic> orders;
  final VoidCallback onRefresh;
  const _OrdersTab({required this.orders, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(child: Text('Teslim edilecek sipariş yok'));
    }
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final order = orders[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.green.shade50,
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            title: Text('Sipariş #${order['id']} - Masa ${order['tableNumber']}'),
            subtitle: Text('${order['items']?.length ?? 0} ürün hazır'),
            trailing: FilledButton(
              onPressed: () => _deliver(context, order['id']),
              child: const Text('Teslim Et'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deliver(BuildContext context, dynamic orderId) async {
    await ApiClient.instance.post('/waiter/orders/$orderId/deliver');
    onRefresh();
  }
}
