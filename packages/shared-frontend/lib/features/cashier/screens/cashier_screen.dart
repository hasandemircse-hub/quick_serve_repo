import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/widgets/critical_fallback_snackbar.dart';
import '../../../core/widgets/offline_status_banner.dart';
import '../../../core/widgets/sync_lag_indicator.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');

  List<dynamic> _tables = [];
  List<dynamic> _sessionOrders = [];
  List<dynamic> _sessionPayments = [];
  Map<String, dynamic>? _sessionFinancialSummary;
  Map<int, Map<String, dynamic>> _orderFinancialById = {};
  final Map<int, int> _includedItemUnits = <int, int>{};
  dynamic _selectedTable;
  bool _loading = true;
  bool _processingPayment = false;
  String _method = 'CASH';
  int _splitCount = 1;
  final Map<int, int> _openTableSeenOrder = <int, int>{};
  int _openTableOrderSeed = 0;
  int? _restaurantId;
  bool _posDeviceEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadTables();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapSessionContext();
    });
  }

  @override
  void dispose() {
    final restaurantId = _restaurantId;
    if (restaurantId != null) {
      WebSocketService.instance.unsubscribe('/topic/restaurant/$restaurantId/tables');
      WebSocketService.instance.unsubscribe('/topic/restaurant/$restaurantId/orders');
    }
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.waiterTables);
      final tables = List<dynamic>.from(res.data as List? ?? const []);
      final openTableIds = tables
          .where((t) => t['activeSessionId'] != null)
          .map((t) => (t['id'] as num?)?.toInt())
          .whereType<int>()
          .toSet();
      for (final id in openTableIds) {
        _openTableSeenOrder.putIfAbsent(id, () => _openTableOrderSeed++);
      }
      _openTableSeenOrder.removeWhere((id, _) => !openTableIds.contains(id));
      setState(() {
        _tables = tables;
        _loading = false;
      });
      if (_selectedTable != null) {
        final selectedId = _selectedTable['id'];
        final updated = tables.where((t) => t['id'] == selectedId).toList();
        if (updated.isNotEmpty) {
          await _selectTable(updated.first);
        } else {
          setState(() {
            _selectedTable = null;
            _sessionOrders = [];
            _sessionPayments = [];
            _sessionFinancialSummary = null;
            _orderFinancialById = {};
            _includedItemUnits.clear();
          });
        }
      }
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        showCriticalFallbackSnackBar(
          context,
          actionLabel: 'Kasa masa listesi yenileme',
          error: 'table_load_failed',
          onRetry: _loadTables,
        );
      }
    }
  }

  Future<void> _bootstrapSessionContext() async {
    final userInfo = await LocalStorage.getUserInfo();
    if (!mounted) return;
    final pos = userInfo['isPosDeviceEnabled'] == true;
    setState(() {
      _posDeviceEnabled = pos;
      if (!pos && _method == 'POS_CARD') _method = 'CASH';
    });
    await _initRealtime(userInfo);
  }

  Future<void> _initRealtime(Map<String, dynamic> userInfo) async {
    final restaurantId = userInfo['restaurantId'];
    if (restaurantId is! int) return;
    _restaurantId = restaurantId;
    WebSocketService.instance.subscribeRestaurant(
      restaurantId,
      'tables',
      _handleTableEvent,
    );
    WebSocketService.instance.subscribeRestaurant(
      restaurantId,
      'orders',
      _handleOrderEvent,
    );
  }

  void _handleTableEvent(dynamic payload) {
    if (!mounted || payload is! String) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final status = (decoded['status'] ?? '').toString();
      final tableId = (decoded['tableId'] as num?)?.toInt();
      final tableNumber = decoded['tableNumber']?.toString();

      if (status == 'OCCUPIED') {
        if (tableId != null && !_openTableSeenOrder.containsKey(tableId)) {
          _openTableSeenOrder[tableId] = _openTableOrderSeed++;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tableNumber != null && tableNumber.isNotEmpty
                  ? 'Yeni masa açıldı: Masa $tableNumber'
                  : 'Yeni masa açıldı',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _loadTables();
    } catch (_) {
      // parse hatalarında sessiz geç
      if (mounted) {
        showCriticalFallbackSnackBar(
          context,
          actionLabel: 'Masa event işleme',
          error: 'table_event_parse_failed',
          onRetry: _loadTables,
        );
      }
    }
  }

  void _handleOrderEvent(dynamic payload) {
    if (!mounted || payload is! String) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final selectedSessionId = (_selectedTable?['activeSessionId'] as num?)?.toInt();
      final eventSessionId = (decoded['tableSessionId'] as num?)?.toInt();
      if (selectedSessionId == null || eventSessionId == null || selectedSessionId != eventSessionId) {
        return;
      }
      _loadSessionOrders(selectedSessionId);
      _loadSessionFinancialSummary(selectedSessionId);
    } catch (_) {
      // parse hatalarında sessiz geç
      if (mounted && _selectedTable != null) {
        final sessionId = _selectedTable['activeSessionId'];
        if (sessionId != null) {
          showCriticalFallbackSnackBar(
            context,
            actionLabel: 'Sipariş event işleme',
            error: 'order_event_parse_failed',
            onRetry: () {
              _loadSessionOrders(sessionId);
              _loadSessionFinancialSummary(sessionId);
            },
          );
        }
      }
    }
  }

  Future<void> _selectTable(dynamic table) async {
    final sessionId = table['activeSessionId'];
    if (sessionId == null) return;
    setState(() {
      _selectedTable = table;
      _sessionOrders = [];
      _sessionPayments = [];
      _sessionFinancialSummary = null;
      _orderFinancialById = {};
    });
    await Future.wait([
      _loadSessionOrders(sessionId),
      _loadSessionPayments(sessionId),
      _loadSessionFinancialSummary(sessionId),
    ]);
  }

  Future<void> _loadSessionOrders(dynamic sessionId) async {
    final res = await ApiClient.instance.get('${ApiConstants.waiterSessionOrders}/$sessionId/orders');
    final orders = List<dynamic>.from(res.data as List? ?? const []);
    final existingItemIds = orders
        .expand((o) => _orderItems(o))
        .map((it) => it['id'])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    final deliveredItems = orders
        .where((o) => (o['status'] ?? '').toString() == 'DELIVERED')
        .expand((o) => _orderItems(o))
        .toList();

    setState(() {
      _sessionOrders = orders;
      _includedItemUnits.removeWhere((id, _) => !existingItemIds.contains(id));
      for (final raw in deliveredItems) {
        final item = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
        final itemId = _itemId(item);
        if (itemId <= 0) continue;
        final qty = _itemQuantity(item);
        final current = _includedItemUnits[itemId] ?? 0;
        if (current < qty) {
          _includedItemUnits[itemId] = qty;
        }
      }
    });
  }

  Future<void> _loadSessionPayments(dynamic sessionId) async {
    final res = await ApiClient.instance.get('${ApiConstants.waiterSessionOrders}/$sessionId/payments');
    final payments = List<dynamic>.from(res.data as List? ?? const []);
    setState(() => _sessionPayments = payments);
  }

  Future<void> _loadSessionFinancialSummary(dynamic sessionId) async {
    final res = await ApiClient.instance
        .get('${ApiConstants.waiterSessionOrders}/$sessionId/financial-summary');
    final data = Map<String, dynamic>.from(res.data as Map? ?? const {});
    final orders = List<dynamic>.from(data['orders'] as List? ?? const []);
    final byId = <int, Map<String, dynamic>>{};
    for (final o in orders) {
      if (o is! Map) continue;
      final map = Map<String, dynamic>.from(o);
      final id = (map['orderId'] as num?)?.toInt();
      if (id != null) byId[id] = map;
    }
    setState(() {
      _sessionFinancialSummary = data;
      _orderFinancialById = byId;
    });
  }

  double _toDouble(dynamic n) => (n as num?)?.toDouble() ?? 0;

  List<dynamic> get _includedOrders =>
      _sessionOrders.where((o) => _orderIncludedItemCount(o) > 0).toList();

  List<dynamic> get _baseSortedOrders {
    final orders = List<dynamic>.from(_sessionOrders);
    orders.sort((a, b) {
      final aDelivered = (a['status'] ?? '').toString() == 'DELIVERED';
      final bDelivered = (b['status'] ?? '').toString() == 'DELIVERED';
      if (aDelivered != bDelivered) return aDelivered ? -1 : 1;

      final aDate = _orderDate(a);
      final bDate = _orderDate(b);
      if (aDate != null && bDate != null) {
        return aDate.compareTo(bDate);
      }
      if (aDate != null) return -1;
      if (bDate != null) return 1;
      return _orderId(a).compareTo(_orderId(b));
    });
    return orders;
  }

  List<dynamic> get _sortedOrders {
    final base = _baseSortedOrders;
    final withIndex = base.asMap().entries.toList();
    withIndex.sort((a, b) {
      final aOrder = a.value;
      final bOrder = b.value;
      final aPaid = _orderPaymentStatus(aOrder) == 'PAID';
      final bPaid = _orderPaymentStatus(bOrder) == 'PAID';
      if (aPaid != bPaid) return aPaid ? 1 : -1; // paid olanlar en altta
      return a.key.compareTo(b.key);
    });
    return withIndex.map((e) => e.value).toList();
  }

  double get _billableSubtotal => _sessionOrders.fold<double>(
      0, (sum, order) => sum + _includedOrderAmount(order));

  double get _discount => double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _netSubtotal => (_billableSubtotal - _discount).clamp(0, double.infinity);

  double get _vatAmount => _netSubtotal * 0.10;

  double get _grandTotal => _netSubtotal;

  double get _paidTotal {
    if (_sessionFinancialSummary != null) {
      return _toDouble(_sessionFinancialSummary!['paidTotal']);
    }
    return _sessionPayments
        .where((p) => p['status'] == 'COMPLETED')
        .fold<double>(0, (s, p) => s + _toDouble(p['amount']) + _toDouble(p['tipAmount']));
  }

  double get _balance => _grandTotal - _paidTotal;
  double get _remaining => _balance > 0 ? _balance : 0;
  double get _sessionTotal {
    if (_sessionFinancialSummary != null) return _toDouble(_sessionFinancialSummary!['sessionTotal']);
    return _sessionOrders
        .where((o) => (o['status'] ?? '').toString() != 'CANCELLED')
        .fold<double>(0, (s, o) => s + _toDouble(o['totalAmount']));
  }
  double get _sessionOutstanding {
    if (_sessionFinancialSummary != null) {
      return _toDouble(_sessionFinancialSummary!['outstandingAmount']);
    }
    return (_sessionTotal - _paidTotal).clamp(0, double.infinity);
  }

  Future<void> _takePayment() async {
    if (_selectedTable == null) return;
    final sessionId = _selectedTable['activeSessionId'];
    if (sessionId == null) return;

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;

    if (_method == 'POS_CARD' && !_posDeviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu restoran için POS cihaz kullanımı kapalı.'),
        ),
      );
      return;
    }

    if (_sessionOutstanding <= 0.01) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bu masada borç yok'),
          content: Text(
            'Bu tahsilat fazla ödeme olarak kaydedilecek.\n'
            'Tutar: ${amount.toStringAsFixed(2)}\n\n'
            'Devam edilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Devam'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _processingPayment = true);
    try {
      if (_method == 'POS_CARD') {
        await _takePosPayment(sessionId, amount);
      } else {
        await ApiClient.instance.post(
          '${ApiConstants.waiterSessionOrders}/$sessionId/payments/cash',
          data: {
            'method': _method,
            'amount': amount,
            'tipAmount': 0,
            'allocations': _buildAllocationsForPayment(sessionId, amount),
          },
        );
      }

      await _loadSessionPayments(sessionId);
      await _loadSessionFinancialSummary(sessionId);
      await _loadTables();
      _amountCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_method == 'POS_CARD'
              ? 'POS işlemi tamamlandı.'
              : 'Ödeme başarıyla alındı.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCriticalFallbackSnackBar(
        context,
        actionLabel: 'Ödeme alma',
        error: e,
        onRetry: _takePayment,
      );
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  Future<void> _takePosPayment(dynamic sessionId, double amount) async {
    final idempotencyKey = 'pos-$sessionId-${DateTime.now().millisecondsSinceEpoch}';
    final initRes = await ApiClient.instance.post(
      '${ApiConstants.waiterSessionOrders}/$sessionId/payments/pos/init',
      data: {
        'amount': amount,
        'tipAmount': 0,
        'terminalId': 'CASHIER_WEB',
        'idempotencyKey': idempotencyKey,
        'allocations': _buildAllocationsForPayment(sessionId, amount),
      },
    );

    final initData = Map<String, dynamic>.from(initRes.data as Map? ?? const {});
    final posIntentId = (initData['posIntentId'] ?? '').toString();
    if (posIntentId.isEmpty) {
      throw Exception('POS intent oluşturulamadı');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('POS işlemi başlatıldı. Kartı POS cihazından okutun.'),
        duration: Duration(seconds: 2),
      ),
    );

    final result = await _showPosResultDialog(sessionId, posIntentId);
    if (result == null) {
      await ApiClient.instance.post(
        '${ApiConstants.waiterSessionOrders}/$sessionId/payments/pos/$posIntentId/cancel',
        data: {'timeout': true},
      );
      throw Exception('POS işlemi zaman aşımına uğradı');
    }

    await ApiClient.instance.post(
      '${ApiConstants.waiterSessionOrders}/$sessionId/payments/pos/$posIntentId/confirm',
      data: {
        'success': result,
        'providerRawStatus': result ? 'APPROVED' : 'DECLINED',
        'failureReason': result ? null : 'POS cihazı işlemi reddetti',
      },
    );

    if (!result) {
      throw Exception('POS işlemi başarısız');
    }
  }

  Future<bool?> _showPosResultDialog(dynamic sessionId, String posIntentId) async {
    bool busy = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit(bool success) async {
              if (busy) return;
              setLocal(() => busy = true);
              try {
                Navigator.pop(ctx, success);
              } finally {
                setLocal(() => busy = false);
              }
            }

            Future<void> timeout() async {
              if (busy) return;
              setLocal(() => busy = true);
              try {
                Navigator.pop(ctx, null);
              } finally {
                setLocal(() => busy = false);
              }
            }

            return AlertDialog(
              title: const Text('POS Ödeme Bekleniyor'),
              content: Text(
                'POS intent: $posIntentId\n'
                'Kart çekildiyse "Başarılı", red aldıysa "Başarısız" seçin.',
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : timeout,
                  child: const Text('Zaman Aşımı'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => submit(false),
                  child: const Text('Başarısız'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => submit(true),
                  child: const Text('Başarılı'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _printBill() async {
    if (_selectedTable == null) return;

    final tableLabel = 'Masa ${_selectedTable['tableNumber']}';
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('QuickServe - Hesap Ozeti',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(tableLabel),
            pw.Text('Tarih: ${DateTime.now()}'),
            pw.SizedBox(height: 12),
            pw.Divider(),
            ..._includedOrders.map((o) {
              final id = o['id'];
              final selectedItems = _orderItems(o)
                  .where((it) => _selectedUnitsForItem(it) > 0)
                  .toList();
              final total = _includedOrderAmount(o).toStringAsFixed(2);
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [pw.Text('Siparis #$id'), pw.Text('TRY $total')],
                    ),
                  ),
                  ...selectedItems.map((it) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                        child: pw.Text(
                          '${_selectedUnitsForItem(it)}x ${(it['menuItemName'] ?? '').toString()}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      )),
                ],
              );
            }),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Ara Toplam'), pw.Text('TRY ${_billableSubtotal.toStringAsFixed(2)}')],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Indirim'), pw.Text('-TRY ${_discount.toStringAsFixed(2)}')],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('KDV (10%)'), pw.Text('TRY ${_vatAmount.toStringAsFixed(2)}')],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Genel Toplam', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('TRY ${_grandTotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Odenen'), pw.Text('TRY ${_paidTotal.toStringAsFixed(2)}')],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text('Kalan'), pw.Text('TRY ${_remaining.toStringAsFixed(2)}')],
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    // Kasa için asıl kaynak açık oturumdur; masa status senkronu gecikse bile
    // activeSessionId doluysa tahsilat ekranında görünmelidir.
    final occupied = _tables.where((t) => t['activeSessionId'] != null).toList();
    occupied.sort((a, b) {
      final aId = (a['id'] as num?)?.toInt();
      final bId = (b['id'] as num?)?.toInt();
      return (_openTableSeenOrder[aId] ?? 1 << 30).compareTo(
        _openTableSeenOrder[bId] ?? 1 << 30,
      );
    });
    final query = _searchCtrl.text.toLowerCase().trim();
    final filtered = occupied.where((t) {
      final n = (t['tableNumber'] ?? '').toString().toLowerCase();
      return query.isEmpty || n.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasa Ekrani'),
        actions: [
          IconButton(onPressed: _loadTables, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () => context.go('/waiter'),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Garson ekranina don',
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineStatusBanner(),
          const SyncLagIndicator(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(flex: 3, child: _buildTablesPanel(filtered)),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 5, child: _buildOrderPanel()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 4, child: _buildPaymentPanel()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablesPanel(List<dynamic> tables) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Masa ara...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Acik Masalar (${tables.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: tables.length,
              itemBuilder: (_, i) {
                final t = tables[i];
                final selected = _selectedTable?['id'] == t['id'];
                return Card(
                  color: selected ? Colors.blue.shade50 : null,
                  child: ListTile(
                    onTap: () => _selectTable(t),
                    leading: const Icon(Icons.table_restaurant),
                    title: Text('Masa ${t['tableNumber']}'),
                    subtitle: Text('Session #${t['activeSessionId'] ?? '-'}'),
                    trailing: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPanel() {
    if (_selectedTable == null) {
      return const Center(child: Text('Soldan bir masa secin'));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Siparis Detayi - Masa ${_selectedTable['tableNumber']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: _buildOrdersList(
              orders: _sortedOrders,
              emptyText: 'Bu masada siparis bulunamadi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList({
    required List<dynamic> orders,
    required String emptyText,
  }) {
    if (orders.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (_, index) {
        final order = orders[index];
        final items = List<dynamic>.from(order['items'] as List? ?? const []);
        final status = (order['status'] ?? '').toString();
        final allIncluded = _isOrderFullyIncluded(order);
        final hasIncludedItem = _orderIncludedItemCount(order) > 0;
        final isCancelled = status == 'CANCELLED';
        final coveredAmount = _coveredAmountForOrder(order);
        final orderTotalForPayment = _toDouble(order['totalAmount']);
        final paymentStatus = _orderPaymentStatus(order);
        final isPaid = paymentStatus == 'PAID';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Siparis #${order['id']}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'TRY ${_toDouble(order['totalAmount']).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: (isCancelled || isPaid)
                          ? null
                          : () => setState(() {
                                final itemIds = _orderItemIds(order);
                                if (allIncluded) {
                                  for (final itemId in itemIds) {
                                    _includedItemUnits.remove(itemId);
                                  }
                                } else {
                                  for (final it in _orderItems(order)) {
                                    final itemId = _itemId(it);
                                    if (itemId <= 0) continue;
                                    _includedItemUnits[itemId] = _itemQuantity(it);
                                  }
                                }
                              }),
                      style: FilledButton.styleFrom(
                        backgroundColor: isPaid
                            ? Colors.grey.shade400
                            : (hasIncludedItem ? Colors.green.shade600 : Colors.red.shade600),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        isPaid ? 'Odendi' : (allIncluded ? 'Hesaptan Cikar' : 'Hesaba Ekle'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statusBadge(status),
                    const SizedBox(width: 6),
                    _paymentBadge(paymentStatus),
                  ],
                ),
                if (orderTotalForPayment > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Odeme: TRY ${coveredAmount.clamp(0.0, orderTotalForPayment).toStringAsFixed(2)} / ${orderTotalForPayment.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  ...items.map((it) {
                    final qty = _itemQuantity(it);
                    final name = (it['menuItemName'] ?? '').toString();
                    final itemId = _itemId(it);
                    final includedUnits = _selectedUnitsForItem(it);
                    return Column(
                      children: List.generate(qty, (idx) {
                        final unitNo = idx + 1;
                        final selectedUnit = unitNo <= includedUnits;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '$unitNo.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$name ($unitNo)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: (isCancelled || isPaid)
                                    ? null
                                    : () => setState(() {
                                          if (selectedUnit) {
                                            final next = unitNo - 1;
                                            if (next <= 0) {
                                              _includedItemUnits.remove(itemId);
                                            } else {
                                              _includedItemUnits[itemId] = next;
                                            }
                                          } else {
                                            _includedItemUnits[itemId] = unitNo;
                                          }
                                        }),
                                style: FilledButton.styleFrom(
                                  backgroundColor: (isCancelled || isPaid)
                                      ? Colors.grey.shade400
                                      : (selectedUnit ? Colors.green.shade600 : Colors.red.shade600),
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                child: Text(
                                  (isCancelled || isPaid)
                                      ? 'Pasif'
                                      : (selectedUnit ? 'Cikar' : 'Ekle'),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'TRY ${_itemUnitPrice(it).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _statusColor(status).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _statusLabel(status),
          style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _paymentBadge(String paymentStatus) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _paymentStatusColor(paymentStatus).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _paymentStatusLabel(paymentStatus),
          style: TextStyle(
              color: _paymentStatusColor(paymentStatus), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _buildPaymentPanel() {
    if (_selectedTable == null) {
      return const Center(child: Text('Odeme paneli icin masa secin'));
    }
    final perSplit = _splitCount > 0 ? (_remaining / _splitCount) : _remaining;
    final activeOrders = _sessionOrders
        .where((o) => (o['status'] ?? '').toString() != 'CANCELLED')
        .toList();
    final noOrders = activeOrders.isEmpty;
    final allPaid = activeOrders.isNotEmpty &&
        activeOrders.every((o) => _orderPaymentStatus(o) == 'PAID');
    final showReadyToCloseTag = noOrders || allPaid;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          const Text('Odeme ve Toplam',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (showReadyToCloseTag) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                noOrders
                    ? 'Masa aktif, sipariş yok (manuel kapatma bekliyor)'
                    : 'Tüm siparişler ödendi (manuel kapatma bekliyor)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildPaymentHeadline(),
          const SizedBox(height: 12),
          TextField(
            controller: _discountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Indirim (TRY)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Split: '),
              DropdownButton<int>(
                value: _splitCount,
                items: [1, 2, 3, 4, 5, 6]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n kisi')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _splitCount = v);
                },
              ),
              const Spacer(),
              Text('Kisi basi: TRY ${perSplit.toStringAsFixed(2)}'),
            ],
          ),
          const Divider(),
          _sumRow('Ara Toplam', _billableSubtotal),
          _sumRow('Indirim', -_discount),
          _sumRow('KDV (10%)', _vatAmount),
          _sumRow('Genel Toplam', _grandTotal, bold: true),
          _sumRow('Odenen', _paidTotal),
          _sumRow('Kalan', _remaining, bold: true, color: Colors.red),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _methodChip('CASH', 'Nakit'),
              if (_posDeviceEnabled) _methodChip('POS_CARD', 'POS Kart'),
              _methodChip('CREDIT_CARD', 'Online Kart'),
              _methodChip('OTHER', 'Yemek Ceki/Diger'),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Tahsil edilecek tutar',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() {
                  _amountCtrl.text = perSplit.toStringAsFixed(2);
                }),
                icon: const Icon(Icons.calculate),
                tooltip: 'Split tutarini ata',
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _processingPayment ? null : _takePayment,
              icon: const Icon(Icons.payments),
              label: Text(_processingPayment ? 'Isleniyor...' : 'Tahsilat Al'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _printBill,
              icon: const Icon(Icons.print),
              label: const Text('Adisyon Yazdir'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _closeTableFromCashier,
              icon: const Icon(Icons.logout),
              label: const Text('Masayi Kapat'),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Card(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sessionPayments.length,
                itemBuilder: (_, i) {
                  final p = _sessionPayments[i];
                  final allocations = List<dynamic>.from(p['allocations'] as List? ?? const []);
                  return ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.receipt_long),
                    title: Text(
                      '${_paymentMethodLabel((p['method'] ?? '').toString())} - '
                      '${_paymentRecordStatusLabel((p['status'] ?? '').toString())}',
                    ),
                    subtitle: allocations.isEmpty
                        ? const Text('Dagitim detayi yok')
                        : Text('Dagitim: ${allocations.length} satir'),
                    trailing: Text(
                      'TRY ${(_toDouble(p['amount']) + _toDouble(p['tipAmount'])).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    children: allocations.isEmpty
                        ? const [
                            ListTile(
                              dense: true,
                              title: Text('Bu odemede allocation bilgisi kayitli degil'),
                            ),
                          ]
                        : allocations.map((a) {
                            final type = (a['targetType'] ?? '').toString();
                            final targetId = (a['targetId'] as num?)?.toInt();
                            final amount = _toDouble(a['amount']);
                            return ListTile(
                              dense: true,
                              title: Text(_allocationLabel(type, targetId)),
                              trailing: Text('TRY ${amount.toStringAsFixed(2)}'),
                            );
                          }).toList(),
                  );
                },
              ),
            ),
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHeadline() {
    final hasDebt = _balance > 0.01;
    final hasOverpayment = _balance < -0.01;
    final balanceLabel = hasOverpayment ? 'Fazla Odeme' : 'Kalan Borc';
    final balanceValue = hasOverpayment ? -_balance : _remaining;
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Odenen Toplam',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _paidTotal.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Toplam Borc',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _grandTotal.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hasOverpayment
                    ? Colors.amber.shade50
                    : (hasDebt ? Colors.red.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasOverpayment
                      ? Colors.amber.shade200
                      : (hasDebt ? Colors.red.shade100 : Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    balanceLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasOverpayment
                          ? Colors.amber.shade900
                          : (hasDebt ? Colors.red.shade700 : Colors.black87),
                    ),
                  ),
                  Text(
                    balanceValue.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: hasOverpayment
                          ? Colors.amber.shade900
                          : (hasDebt ? Colors.red.shade700 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodChip(String value, String label) {
    final selected = _method == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _method = value),
    );
  }

  Widget _sumRow(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            'TRY ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'PENDING' => 'Bekleniyor',
        'PREPARING' => 'Hazirlaniyor',
        'READY' => 'Hazir',
        'DELIVERED' => 'Teslim edildi',
        'CANCELLED' => 'Iptal',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'PENDING' => Colors.orange,
        'PREPARING' => Colors.blue,
        'READY' => Colors.green,
        'DELIVERED' => Colors.grey,
        'CANCELLED' => Colors.red,
        _ => Colors.black54,
      };

  int _orderId(dynamic order) => (order['id'] as num?)?.toInt() ?? -1;
  List<dynamic> _orderItems(dynamic order) => List<dynamic>.from(order['items'] as List? ?? const []);
  int _itemId(dynamic item) => (item['id'] as num?)?.toInt() ?? -1;
  int _itemQuantity(dynamic item) => (item['quantity'] as num?)?.toInt() ?? 0;
  double _itemUnitPrice(dynamic item) {
    final qty = _itemQuantity(item);
    if (qty <= 0) return 0;
    return _itemLineTotal(item) / qty;
  }
  int _selectedUnitsForItem(dynamic item) {
    final itemId = _itemId(item);
    if (itemId <= 0) return 0;
    final selected = _includedItemUnits[itemId] ?? 0;
    final qty = _itemQuantity(item);
    if (qty <= 0) return 0;
    return selected.clamp(0, qty).toInt();
  }
  double _itemLineTotal(dynamic item) =>
      _toDouble(item['unitPrice']) * _toDouble(item['quantity']);
  Set<int> _orderItemIds(dynamic order) => _orderItems(order)
      .map((it) => _itemId(it))
      .where((id) => id > 0)
      .toSet();
  bool _isOrderFullyIncluded(dynamic order) {
    final items = _orderItems(order);
    return items.isNotEmpty && items.every((it) => _selectedUnitsForItem(it) >= _itemQuantity(it));
  }
  int _orderIncludedItemCount(dynamic order) =>
      _orderItems(order).where((it) => _selectedUnitsForItem(it) > 0).length;
  double _includedOrderAmount(dynamic order) => _orderItems(order)
      .fold<double>(0, (sum, it) => sum + (_selectedUnitsForItem(it) * _itemUnitPrice(it)));

  double _coveredAmountForOrder(dynamic order) {
    final financial = _orderFinancialById[_orderId(order)];
    if (financial != null) return _toDouble(financial['paidAmount']);
    return 0;
  }

  String _paymentStatusFor(double total, double covered) {
    if (total <= 0.0001) return 'NOT_INCLUDED';
    if (covered <= 0.0001) return 'UNPAID';
    if (covered + 0.0001 >= total) return 'PAID';
    return 'PARTIAL';
  }

  String _orderPaymentStatus(dynamic order) {
    final financial = _orderFinancialById[_orderId(order)];
    final fromApi = (financial?['paymentStatus'] ?? '').toString().trim();
    if (fromApi.isNotEmpty) return fromApi;
    return _paymentStatusFor(_toDouble(order['totalAmount']), _coveredAmountForOrder(order));
  }

  List<Map<String, dynamic>> _buildAllocationsForPayment(dynamic sessionId, double amount) {
    if (amount <= 0) return const [];
    if (_sessionOutstanding <= 0.01) {
      return [
        {
          'targetType': 'SESSION',
          'targetId': (sessionId as num).toInt(),
          'amount': double.parse(amount.toStringAsFixed(2)),
        },
      ];
    }
    final selectedItems = <Map<String, dynamic>>[];
    for (final order in _baseSortedOrders) {
      for (final item in _orderItems(order)) {
        if (_selectedUnitsForItem(item) > 0) {
          selectedItems.add(Map<String, dynamic>.from(item));
        }
      }
    }

    double remaining = amount;
    final allocations = <Map<String, dynamic>>[];
    for (final item in selectedItems) {
      if (remaining <= 0.0001) break;
      final line = _selectedUnitsForItem(item) * _itemUnitPrice(item);
      if (line <= 0) continue;
      final applied = remaining >= line ? line : remaining;
      allocations.add({
        'targetType': 'ORDER_ITEM',
        'targetId': _itemId(item),
        'amount': double.parse(applied.toStringAsFixed(2)),
      });
      remaining -= applied;
    }

    if (remaining > 0.0001) {
      allocations.add({
        'targetType': 'SESSION',
        'targetId': (sessionId as num).toInt(),
        'amount': double.parse(remaining.toStringAsFixed(2)),
      });
    }
    return allocations;
  }

  String _paymentStatusLabel(String status) => switch (status) {
        'PAID' => 'Odendi',
        'PARTIAL' => 'Kismi Odeme',
        'UNPAID' => 'Odenmedi',
        'NOT_INCLUDED' => 'Hesaba Dahil Degil',
        _ => status,
      };

  String _paymentMethodLabel(String method) => switch (method) {
        'CASH' => 'Nakit',
        'POS_CARD' => 'POS Kart',
        'CREDIT_CARD' => 'Online Kart',
        'DEBIT_CARD' => 'Banka Kartı',
        'OTHER' => 'Diğer',
        _ => method,
      };

  String _paymentRecordStatusLabel(String status) => switch (status) {
        'COMPLETED' => 'Tamamlandı',
        'PENDING' => 'Beklemede',
        'FAILED' => 'Başarısız',
        'TIMEOUT' => 'Zaman Aşımı',
        _ => status,
      };

  Color _paymentStatusColor(String status) => switch (status) {
        'PAID' => Colors.green,
        'PARTIAL' => Colors.orange,
        'UNPAID' => Colors.red,
        'NOT_INCLUDED' => Colors.grey,
        _ => Colors.black54,
      };

  DateTime? _orderDate(dynamic order) {
    final raw = order['createdAt'];
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _closeTableFromCashier() async {
    if (_selectedTable == null) return;
    final sessionId = _selectedTable['activeSessionId'];
    if (sessionId == null) return;

    if (_sessionOutstanding > 0.01) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Masa tamamen odenmedi'),
          content: Text(
            'Bu masa icin TRY ${_sessionOutstanding.toStringAsFixed(2)} kalan bakiye var. '
            'Yine de kapatmak istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yine de Kapat'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await ApiClient.instance.post('/waiter/sessions/$sessionId/close', data: {'reason': 'PAID_BILL'});
      await _loadTables();
      setState(() {
        _selectedTable = null;
        _sessionOrders = [];
        _sessionPayments = [];
        _includedItemUnits.clear();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masa kapatildi')),
      );
    } catch (e) {
      if (!mounted) return;
      showCriticalFallbackSnackBar(
        context,
        actionLabel: 'Masa kapatma',
        error: e,
        onRetry: _closeTableFromCashier,
      );
    }
  }

  String _allocationLabel(String type, int? targetId) {
    if (type == 'SESSION') {
      return 'Genel Masa Odemesi';
    }
    if (type == 'ORDER') {
      return targetId != null ? 'Siparis #$targetId' : 'Siparis';
    }
    if (type == 'ORDER_ITEM') {
      final item = _findOrderItemById(targetId);
      if (item != null) {
        final name = (item['menuItemName'] ?? '').toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        return 'Kalem: $name (${qty}x)';
      }
      return targetId != null ? 'Siparis Kalemi #$targetId' : 'Siparis Kalemi';
    }
    return type.isEmpty ? 'Bilinmeyen Dagitim' : type;
  }

  Map<String, dynamic>? _findOrderItemById(int? itemId) {
    if (itemId == null) return null;
    for (final order in _sessionOrders) {
      for (final item in _orderItems(order)) {
        final id = (item['id'] as num?)?.toInt();
        if (id == itemId) {
          return Map<String, dynamic>.from(item as Map);
        }
      }
    }
    return null;
  }
}
