import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/customer_session_provider.dart';
import '../../../core/storage/local_storage.dart';

// ─── Cart State ───────────────────────────────────────────────────────────────

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());

class CartItem {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final int quantity;
  final String? note;

  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
    this.note,
  });

  CartItem copyWith({int? quantity, String? note}) => CartItem(
        id: id,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
      );
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(String id, String name, double price, {String? imageUrl}) {
    final idx = state.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      final updated = [...state];
      updated[idx] = updated[idx].copyWith(quantity: updated[idx].quantity + 1);
      state = updated;
    } else {
      state = [...state, CartItem(id: id, name: name, price: price, imageUrl: imageUrl)];
    }
  }

  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      state = state.where((i) => i.id != id).toList();
    } else {
      state = state.map((i) => i.id == id ? i.copyWith(quantity: quantity) : i).toList();
    }
  }

  void updateNote(String id, String? note) {
    state = state.map((i) => i.id == id ? i.copyWith(note: note) : i).toList();
  }

  int getQuantity(String id) =>
      state.where((i) => i.id == id).firstOrNull?.quantity ?? 0;

  double get total => state.fold(0, (s, i) => s + i.price * i.quantity);
  int get totalCount => state.fold(0, (s, i) => s + i.quantity);

  void clear() => state = [];
}

// ─── Menu Screen ──────────────────────────────────────────────────────────────

class MenuScreen extends ConsumerStatefulWidget {
  final String? qrToken;
  const MenuScreen({super.key, this.qrToken});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  Map<String, List<dynamic>> _menu = {};
  bool _loading = true;
  String? _sessionToken;
  String? _restaurantName;
  String? _tableNumber;
  String _selectedCategory = '';
  String _searchQuery = '';
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  final _categoryScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      if (widget.qrToken != null) {
        final res =
            await ApiClient.instance.get('${ApiConstants.scanQr}/${widget.qrToken}');
        _sessionToken = res.data['sessionToken'];
        _restaurantName = res.data['restaurantName'];
        _tableNumber = res.data['tableNumber'];
        await LocalStorage.saveSessionToken(_sessionToken!);
      } else {
        _sessionToken = await LocalStorage.getSessionToken();
        if (_sessionToken == null) {
          if (mounted) context.go('/scan');
          return;
        }
        final res = await ApiClient.instance
            .get(ApiConstants.customerSession, sessionToken: _sessionToken);
        _restaurantName = res.data['restaurantName'];
        _tableNumber = res.data['tableNumber'];
      }
      if (_sessionToken != null) {
        await ref.read(customerSessionProvider.notifier).setSession(_sessionToken!);
      }
      final cached = LocalStorage.getCachedMenu(0);
      if (cached != null) {
        _parseMenu(cached);
      } else {
        await _loadMenu();
      }
    } catch (_) {
      if (mounted) context.go('/scan');
    }
  }

  Future<void> _loadMenu() async {
    try {
      final res = await ApiClient.instance
          .get(ApiConstants.customerMenu, sessionToken: _sessionToken);
      _parseMenu(Map<String, dynamic>.from(res.data));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _parseMenu(Map<String, dynamic> data) {
    final menu = <String, List<dynamic>>{};
    data.forEach((k, v) => menu[k] = List<dynamic>.from(v));
    setState(() {
      _menu = menu;
      _loading = false;
      if (menu.isNotEmpty) _selectedCategory = menu.keys.first;
    });
  }

  void _handleSessionClosed(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(customerSessionProvider.notifier).consumeSessionClosed();
      await LocalStorage.clearSessionToken();
      ref.read(customerSessionProvider.notifier).clearSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      context.go('/scan');
    });
  }

  List<dynamic> get _visibleItems {
    if (_searchQuery.isNotEmpty) {
      return _menu.values
          .expand((list) => list)
          .where((item) => (item['name'] as String? ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return _menu[_selectedCategory] ?? [];
  }

  void _callWaiter() async {
    try {
      await ApiClient.instance
          .post(ApiConstants.customerCallWaiter, sessionToken: _sessionToken);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Garson çağrıldı')));
      }
    } catch (_) {}
  }

  void _requestBill() async {
    try {
      await ApiClient.instance
          .post(ApiConstants.customerCallBill, sessionToken: _sessionToken);
      if (mounted) context.go('/payment');
    } catch (_) {}
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        sessionToken: _sessionToken,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionClosedMessage =
        ref.watch(customerSessionProvider.select((s) => s.sessionClosedMessage));
    if (sessionClosedMessage != null && sessionClosedMessage.isNotEmpty) {
      _handleSessionClosed(sessionClosedMessage);
    }
    final orders = ref.watch(customerSessionProvider.select((s) => s.orders));
    final cartCount =
        ref.watch(cartProvider.select((s) => s.fold(0, (a, i) => a + i.quantity)));
    final cartTotal =
        ref.watch(cartProvider.select((s) => s.fold(0.0, (a, i) => a + i.price * i.quantity)));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _menu.isEmpty
              ? const Center(child: Text('Menü bulunamadı'))
              : Column(
                  children: [
                    _buildCategoryBar(),
                    Expanded(child: _buildList()),
                  ],
                ),
      bottomNavigationBar: _buildBottom(cartCount, cartTotal, orders),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_restaurantName ?? 'Menü',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          if (_tableNumber != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_restaurant,
                    size: 12, color: Colors.black87),
                const SizedBox(width: 4),
                Text('Masa $_tableNumber',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500)),
              ],
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.support_agent),
          tooltip: 'Garson Çağır',
          onPressed: _callWaiter,
        ),
        IconButton(
          icon: const Icon(Icons.receipt_long),
          tooltip: 'Hesap İste',
          onPressed: _requestBill,
        ),
      ],
    );
  }

  // ── Kategori Barı ──────────────────────────────────────────────────────────

  Widget _buildCategoryBar() {
    return Container(
      color: Colors.white,
      height: 50,
      child: Row(
        children: [
          // Kategoriler — arama açılınca sola sıkışır
          Expanded(
            child: ListView.builder(
              controller: _categoryScrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              itemCount: _menu.keys.length,
              itemBuilder: (_, i) {
                final cat = _menu.keys.elementAt(i);
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Arama alanı — sağdan genişler
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _searchActive ? 180 : 44,
            height: 50,
            child: _searchActive
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Ara...',
                            hintStyle: TextStyle(fontSize: 13),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 8),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _searchActive = false;
                          _searchQuery = '';
                          _searchCtrl.clear();
                        }),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.close, size: 20, color: Colors.grey),
                        ),
                      ),
                    ],
                  )
                : IconButton(
                    icon: const Icon(Icons.search, size: 22),
                    onPressed: () => setState(() => _searchActive = true),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Ürün Listesi ───────────────────────────────────────────────────────────

  Widget _buildList() {
    final items = _visibleItems;
    if (items.isEmpty) {
      return const Center(
          child: Text('Ürün bulunamadı', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: items.length,
      itemBuilder: (_, i) => _ProductCard(
        item: Map<String, dynamic>.from(items[i]),
      ),
    );
  }

  // ── Alt Bar ────────────────────────────────────────────────────────────────

  Widget _buildBottom(int cartCount, double cartTotal, List<dynamic> orders) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sepet çubuğu
          if (cartCount > 0)
            GestureDetector(
              onTap: _showCartSheet,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -200) _showCartSheet();
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$cartCount ürün',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₺${cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text('Sepeti Gör',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_up,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          // Siparişler | Garson Çağır | Hesap İste
          Container(
            height: 52,
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buildOrderStatusButton(orders)),
                const VerticalDivider(indent: 10, endIndent: 10, width: 1),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.support_agent, size: 20),
                    label: const Text('Garson'),
                    onPressed: _callWaiter,
                  ),
                ),
                const VerticalDivider(indent: 10, endIndent: 10, width: 1),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.receipt_long, size: 20),
                    label: const Text('Hesap'),
                    onPressed: _requestBill,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusButton(List<dynamic> orders) {
    if (orders.isEmpty) {
      return TextButton.icon(
        icon: const Icon(Icons.receipt_outlined, size: 20),
        label: const Text('Siparişler'),
        onPressed: _showOrdersSheet,
      );
    }

    // En öncelikli aktif durumu bul: READY > PREPARING > PENDING
    const priority = ['READY', 'PREPARING', 'PENDING'];
    final active = orders.where((o) {
      final s = o['status'] as String?;
      return s != 'DELIVERED' && s != 'CANCELLED';
    }).toList();

    final String topStatus;
    if (active.isEmpty) {
      topStatus = 'DELIVERED';
    } else {
      topStatus = active
          .map((o) => o['status'] as String? ?? '')
          .reduce((a, b) =>
              (priority.contains(a) &&
                      priority.indexOf(a) <= priority.indexOf(b))
                  ? a
                  : b);
    }

    final totalAmount = orders
        .where((o) => o['status'] != 'CANCELLED')
        .fold<double>(
            0, (s, o) => s + ((o['totalAmount'] as num?)?.toDouble() ?? 0));

    final info = _orderStatusInfo(topStatus);

    return InkWell(
      onTap: _showOrdersSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info.icon, size: 17, color: info.color),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: info.color),
                      overflow: TextOverflow.ellipsis),
                  Text('₺${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_up,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showOrdersSheet() {
    final orders = ref.read(customerSessionProvider).orders;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrdersSheet(
        orders: orders,
        onRefresh: () => ref.read(customerSessionProvider.notifier).refreshOrders(),
      ),
    );
  }
}

// ─── Sipariş Durumu Yardımcı ──────────────────────────────────────────────────

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusInfo(this.label, this.color, this.icon);
}

_StatusInfo _orderStatusInfo(String status) => switch (status) {
      'PENDING' => const _StatusInfo(
          'Bekleniyor', Colors.orange, Icons.hourglass_top_rounded),
      'PREPARING' => const _StatusInfo(
          'Hazırlanıyor', Colors.blue, Icons.restaurant),
      'READY' => const _StatusInfo(
          'Hazır!', Colors.green, Icons.check_circle_rounded),
      'DELIVERED' => const _StatusInfo(
          'Teslim Edildi', Colors.grey, Icons.done_all),
      'CANCELLED' => const _StatusInfo(
          'İptal', Colors.red, Icons.cancel_outlined),
      _ => const _StatusInfo('Bilinmiyor', Colors.grey, Icons.help_outline),
    };

// ─── Siparişler Bottom Sheet ──────────────────────────────────────────────────

class _OrdersSheet extends StatelessWidget {
  final List<dynamic> orders;
  final VoidCallback onRefresh;
  const _OrdersSheet({required this.orders, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final totalAmount = orders
        .where((o) => o['status'] != 'CANCELLED')
        .fold<double>(
            0, (s, o) => s + ((o['totalAmount'] as num?)?.toDouble() ?? 0));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Başlık + toplam
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined),
                  const SizedBox(width: 8),
                  const Text('Siparişlerim',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Toplam',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                      Text('₺${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      onRefresh();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Liste
            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Text('Henüz sipariş yok',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: orders.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final order = orders[i];
                        final status = order['status'] as String? ?? '';
                        final info = _orderStatusInfo(status);
                        final items =
                            List<dynamic>.from(order['items'] as List? ?? []);
                        final amount =
                            (order['totalAmount'] as num?)?.toDouble() ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Durum + tutar
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: info.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              info.color.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(info.icon,
                                            size: 13, color: info.color),
                                        const SizedBox(width: 5),
                                        Text(info.label,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: info.color,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('₺${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Ürünler
                              ...items.map((item) {
                                final name =
                                    item['menuItemName'] as String? ?? '';
                                final qty = item['quantity'] as int? ?? 1;
                                final note = item['note'] as String?;
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(top: 3, left: 4),
                                  child: Row(
                                    children: [
                                      Text('$qty×',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          note != null && note.isNotEmpty
                                              ? '$name  ($note)'
                                              : name,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ürün Kartı ───────────────────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = item['id'].toString();
    final name = item['name'] as String? ?? '';
    final price = (item['effectivePrice'] as num).toDouble();
    final originalPrice = (item['price'] as num?)?.toDouble();
    final isCampaign = item['isCampaign'] == true;
    final isAvailable =
        item['isAvailable'] == true && item['isRemoved'] != true;
    final imageUrl = item['imageUrl'] as String?;
    final description = item['description'] as String?;

    final qty = ref.watch(
        cartProvider.select((s) => s.where((i) => i.id == id).firstOrNull?.quantity ?? 0));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Stack(
        children: [
          // İçerik
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Görsel
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl != null
                      ? Image.network(imageUrl,
                          width: 86, height: 86, fit: BoxFit.cover)
                      : Container(
                          width: 86,
                          height: 86,
                          color: const Color(0xFFEEEEEE),
                          child: const Icon(Icons.fastfood,
                              size: 36, color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 12),
                // Yazılar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isAvailable ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      if (description != null && description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Fiyat
                      Row(
                        children: [
                          if (isCampaign && originalPrice != null) ...[
                            Text(
                              '₺${originalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 12),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '₺${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isCampaign ? Colors.red : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tükendi overlay
          if (!isAvailable)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Tükendi',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
              ),
            ),

          // Ekle / miktar kontrolü — sağ alt
          if (isAvailable)
            Positioned(
              bottom: 10,
              right: 10,
              child: qty == 0
                  ? SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Ekle',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          minimumSize: const Size(44, 38),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(cartProvider.notifier)
                              .addItem(id, name, price, imageUrl: imageUrl);
                        },
                      ),
                    )
                  : _QtyControl(
                      qty: qty,
                      onAdd: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(cartProvider.notifier)
                            .addItem(id, name, price, imageUrl: imageUrl);
                      },
                      onRemove: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(cartProvider.notifier)
                            .updateQuantity(id, qty - 1);
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _QtyControl(
      {required this.qty, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: Icons.remove, onTap: onRemove),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$qty',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          _Btn(icon: Icons.add, onTap: onAdd),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

// ─── Sepet Bottom Sheet ───────────────────────────────────────────────────────

class _CartSheet extends ConsumerStatefulWidget {
  final String? sessionToken;
  const _CartSheet({required this.sessionToken});

  @override
  ConsumerState<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<_CartSheet> {
  bool _submitting = false;

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final items = cart
          .map((i) => {
                'menuItemId': int.parse(i.id),
                'quantity': i.quantity,
                if (i.note != null && i.note!.isNotEmpty) 'note': i.note,
              })
          .toList();
      await ApiClient.instance.post(
        ApiConstants.customerOrders,
        data: {'items': items},
        sessionToken: widget.sessionToken,
      );
      HapticFeedback.heavyImpact();
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Siparişiniz mutfağa iletildi!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold(0.0, (s, i) => s + i.price * i.quantity);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  const SizedBox(width: 8),
                  const Text('Sepetim',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () {
                            ref.read(cartProvider.notifier).clear();
                          },
                    child: const Text('Temizle',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Ürünler
            Expanded(
              child: cart.isEmpty
                  ? const Center(
                      child: Text('Sepet boş',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: cart.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) =>
                          _CartItemTile(item: cart[i]),
                    ),
            ),
            const Divider(height: 1),
            // Toplam + Onayla
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Toplam',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('₺${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          (_submitting || cart.isEmpty) ? null : _placeOrder,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Siparişi Onayla',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
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
}

// ─── Sepet Ürün Satırı ────────────────────────────────────────────────────────

class _CartItemTile extends ConsumerStatefulWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  ConsumerState<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends ConsumerState<_CartItemTile> {
  bool _noteOpen = false;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.item.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Görsel
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null
                    ? Image.network(item.imageUrl!,
                        width: 48, height: 48, fit: BoxFit.cover)
                    : Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFFEEEEEE),
                        child: const Icon(Icons.fastfood,
                            size: 22, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              // Ad + fiyat
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('₺${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              // Miktar
              Row(
                children: [
                  _SmallBtn(
                    icon: Icons.remove,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(cartProvider.notifier)
                          .updateQuantity(item.id, item.quantity - 1);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('${item.quantity}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _SmallBtn(
                    icon: Icons.add,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).addItem(
                          item.id, item.name, item.price,
                          imageUrl: item.imageUrl);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Not
          GestureDetector(
            onTap: () => setState(() => _noteOpen = !_noteOpen),
            child: Padding(
              padding: const EdgeInsets.only(top: 6, left: 60),
              child: Text(
                item.note?.isNotEmpty == true
                    ? '📝 ${item.note}'
                    : '+ Not ekle',
                style: TextStyle(
                    fontSize: 12,
                    color: item.note?.isNotEmpty == true
                        ? Colors.black87
                        : Colors.blue[700]),
              ),
            ),
          ),
          if (_noteOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(60, 6, 0, 0),
              child: TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  hintText: 'Örn: Soğansız, acısız...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => ref
                    .read(cartProvider.notifier)
                    .updateNote(item.id, v.isEmpty ? null : v),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!)),
          child: Icon(icon, size: 16),
        ),
      );
}
