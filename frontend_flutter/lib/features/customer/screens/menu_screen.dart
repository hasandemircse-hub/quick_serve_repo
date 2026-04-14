import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';

// Basit state: sepet
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  String? note;
  CartItem({required this.id, required this.name, required this.price, this.quantity = 1, this.note});
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(String id, String name, double price) {
    final existing = state.where((i) => i.id == id).firstOrNull;
    if (existing != null) {
      state = state.map((i) => i.id == id
          ? (CartItem(id: i.id, name: i.name, price: i.price, quantity: i.quantity + 1, note: i.note))
          : i).toList();
    } else {
      state = [...state, CartItem(id: id, name: name, price: price)];
    }
  }

  void clear() => state = [];
  int get totalCount => state.fold(0, (sum, i) => sum + i.quantity);
}

class MenuScreen extends ConsumerStatefulWidget {
  final String? qrToken;
  const MenuScreen({super.key, this.qrToken});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> with SingleTickerProviderStateMixin {
  Map<String, List<dynamic>> _menu = {};
  bool _loading = true;
  String? _sessionToken;
  String? _restaurantName;
  String? _tableNumber;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      // Önce QR token ile session aç
      if (widget.qrToken != null) {
        final sessionRes = await ApiClient.instance.get(
            '${ApiConstants.scanQr}/${widget.qrToken}');
        final session = sessionRes.data;
        _sessionToken = session['sessionToken'];
        _restaurantName = session['restaurantName'];
        _tableNumber = session['tableNumber'];
        await LocalStorage.saveSessionToken(_sessionToken!);
      } else {
        _sessionToken = await LocalStorage.getSessionToken();
        if (_sessionToken == null) {
          if (mounted) context.go('/scan');
          return;
        }
        // Oturum bilgisini getir
        final sessionRes = await ApiClient.instance.get(
            ApiConstants.customerSession, sessionToken: _sessionToken);
        _restaurantName = sessionRes.data['restaurantName'];
        _tableNumber = sessionRes.data['tableNumber'];
      }

      // Menüyü yükle (önce cache dene)
      final cached = LocalStorage.getCachedMenu(0);
      if (cached != null) {
        _parseMenu(cached);
      } else {
        await _loadMenu();
      }
    } catch (e) {
      if (mounted) context.go('/scan');
    }
  }

  Future<void> _loadMenu() async {
    try {
      final res = await ApiClient.instance.get(
          ApiConstants.customerMenu, sessionToken: _sessionToken);
      _parseMenu(Map<String, dynamic>.from(res.data));
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  void _parseMenu(Map<String, dynamic> data) {
    final menu = <String, List<dynamic>>{};
    data.forEach((key, value) {
      menu[key] = List<dynamic>.from(value);
    });
    setState(() {
      _menu = menu;
      _loading = false;
      if (menu.isNotEmpty) {
        _tabController = TabController(length: menu.length, vsync: this);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartProvider.notifier).totalCount;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(_restaurantName ?? 'Menü',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_tableNumber != null)
              Text('Masa $_tableNumber',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: cartCount > 0 ? () => context.go('/cart') : null,
              ),
              if (cartCount > 0)
                Positioned(
                  right: 4, top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text('$cartCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
        ],
        bottom: _tabController != null ? TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _menu.keys.map((k) => Tab(text: k)).toList(),
        ) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _menu.isEmpty
          ? const Center(child: Text('Menü bulunamadı'))
          : TabBarView(
        controller: _tabController,
        children: _menu.entries.map((entry) {
          return _CategoryItems(
              items: entry.value,
              onAdd: (item) {
                ref.read(cartProvider.notifier).addItem(
                    item['id'].toString(), item['name'], (item['effectivePrice'] as num).toDouble());
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${item['name']} sepete eklendi'),
                        duration: const Duration(seconds: 1)));
              });
        }).toList(),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.support_agent),
              label: const Text('Garson'),
              onPressed: _callWaiter,
            ),
            TextButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('Hesap'),
              onPressed: _requestBill,
            ),
          ],
        ),
      ),
    );
  }

  void _callWaiter() async {
    await ApiClient.instance.post(ApiConstants.customerCallWaiter, sessionToken: _sessionToken);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Garson çağrıldı')));
    }
  }

  void _requestBill() async {
    await ApiClient.instance.post(ApiConstants.customerCallBill, sessionToken: _sessionToken);
    if (mounted) context.go('/payment');
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}

class _CategoryItems extends StatelessWidget {
  final List<dynamic> items;
  final void Function(Map<String, dynamic>) onAdd;
  const _CategoryItems({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = Map<String, dynamic>.from(items[i]);
        final isAvailable = item['isAvailable'] == true && item['isRemoved'] != true;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: item['imageUrl'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item['imageUrl'], width: 60, height: 60, fit: BoxFit.cover))
                : const Icon(Icons.fastfood, size: 40),
            title: Text(item['name'] ?? '',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isAvailable ? null : Colors.grey)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['description'] != null)
                  Text(item['description'], maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                if (!isAvailable)
                  const Text('Stokta Yok', style: TextStyle(color: Colors.red, fontSize: 11)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item['isCampaign'] == true) ...[
                  Text('${item['price']} ₺',
                      style: const TextStyle(decoration: TextDecoration.lineThrough,
                          color: Colors.grey, fontSize: 12)),
                  Text('${item['effectivePrice']} ₺',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ] else
                  Text('${item['effectivePrice']} ₺',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                if (isAvailable)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFFE53935)),
                    onPressed: () => onAdd(item),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
