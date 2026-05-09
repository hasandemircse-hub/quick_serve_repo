import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/critical_fallback_snackbar.dart';

class _CartLine {
  final int menuItemId;
  final String name;
  final double unitPrice;
  int quantity = 1;

  _CartLine({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
  });
}

/// Garson: dolu masa oturumuna menüden sipariş ekler (`POST /waiter/sessions/{id}/orders`).
class WaiterSessionOrderScreen extends StatefulWidget {
  final int sessionId;
  final String tableNumber;

  const WaiterSessionOrderScreen({
    super.key,
    required this.sessionId,
    required this.tableNumber,
  });

  @override
  State<WaiterSessionOrderScreen> createState() => _WaiterSessionOrderScreenState();
}

class _WaiterSessionOrderScreenState extends State<WaiterSessionOrderScreen> {
  Map<String, List<dynamic>> _menu = {};
  final Map<int, _CartLine> _cart = {};
  bool _loading = true;
  bool _submitting = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.waiterMenu);
      final raw = Map<String, dynamic>.from(res.data as Map? ?? const {});
      final grouped = <String, List<dynamic>>{};
      for (final e in raw.entries) {
        grouped[e.key] = List<dynamic>.from(e.value as List? ?? const []);
      }
      if (mounted) {
        setState(() {
          _menu = grouped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showCriticalFallbackSnackBar(
          context,
          actionLabel: 'Menü yükleme',
          error: e,
          onRetry: _loadMenu,
        );
      }
    }
  }

  void _addItem(Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final name = item['name']?.toString() ?? '';
    final price = _effectivePrice(item);
    setState(() {
      final existing = _cart[id];
      if (existing != null) {
        existing.quantity += 1;
      } else {
        _cart[id] = _CartLine(menuItemId: id, name: name, unitPrice: price);
      }
    });
  }

  double _effectivePrice(Map<String, dynamic> item) {
    final ep = item['effectivePrice'];
    if (ep is num) return ep.toDouble();
    final p = item['price'];
    if (p is num) return p.toDouble();
    return 0;
  }

  int get _cartCount => _cart.values.fold(0, (s, l) => s + l.quantity);

  double get _cartTotal =>
      _cart.values.fold(0.0, (s, l) => s + l.unitPrice * l.quantity);

  List<Map<String, dynamic>> _visibleItemsForCategory(List<dynamic> items) {
    final q = _query.trim().toLowerCase();
    final out = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      if (m['isAvailable'] == false) continue;
      if (m['isRemoved'] == true) continue;
      if (q.isNotEmpty) {
        final name = (m['name'] ?? '').toString().toLowerCase();
        if (!name.contains(q)) continue;
      }
      out.add(m);
    }
    return out;
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final items = _cart.values
          .map((l) => {
                'menuItemId': l.menuItemId,
                'quantity': l.quantity,
              })
          .toList();
      await ApiClient.instance.post(
        '${ApiConstants.waiterSessionOrders}/${widget.sessionId}/orders',
        data: {'items': items},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sipariş mutfağa iletildi')),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        showCriticalFallbackSnackBar(
          context,
          actionLabel: 'Sipariş gönderme',
          error: e,
          onRetry: _submit,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<String> get _categoriesWithVisibleItems {
    final keys = _menu.keys.toList()..sort();
    return keys
        .where((c) => _visibleItemsForCategory(_menu[c] ?? const []).isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesWithVisibleItems;

    return Scaffold(
      appBar: AppBar(
        title: Text('Masa ${widget.tableNumber} · Sipariş'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Ürün ara',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? Center(
                  child: Text(
                    _menu.isEmpty ? 'Menü boş' : 'Aramaya uygun ürün yok',
                  ),
                )
              : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: categories.length,
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final items = _visibleItemsForCategory(_menu[cat] ?? const []);
                return ExpansionTile(
                  initiallyExpanded: i == 0,
                  title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                  children: [
                    for (final item in items)
                      ListTile(
                        title: Text(item['name']?.toString() ?? ''),
                        subtitle: Text(
                          '${_effectivePrice(item).toStringAsFixed(2)} ₺',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          onPressed: () => _addItem(item),
                        ),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Material(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_cartCount ürün', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        '${_cartTotal.toStringAsFixed(2)} ₺',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _cart.isEmpty || _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Mutfağa gönder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
