import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/edge_nodes_cloud_status_strip.dart';

// ════════════════════════════════════════════════════════════════════════════
// SuperadminScreen — Restoran listesi
// ════════════════════════════════════════════════════════════════════════════

class SuperadminScreen extends ConsumerStatefulWidget {
  const SuperadminScreen({super.key});

  @override
  ConsumerState<SuperadminScreen> createState() => _SuperadminScreenState();
}

class _SuperadminScreenState extends ConsumerState<SuperadminScreen> {
  List<dynamic> _restaurants = [];
  Map<int, List<dynamic>> _edgeNodesByRestaurant = {};
  bool _loading = true;
  bool _fleetLoading = false;
  String _username = '';
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final info = await LocalStorage.getUserInfo();
    if (!mounted) return;
    setState(() {
      _username = info['username'] as String? ?? '';
      _fullName = info['fullName'] as String?;
    });
  }

  Future<void> _loadRestaurants() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(
        ApiConstants.superadminRestaurants,
      );
      final restaurants = List<dynamic>.from(res.data);
      setState(() {
        _restaurants = restaurants;
        _loading = false;
      });
      await _loadFleetHealth(restaurants);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFleetHealth(List<dynamic> restaurants) async {
    setState(() => _fleetLoading = true);
    try {
      final futures = restaurants.map((r) async {
        final id = (r['id'] as num?)?.toInt();
        if (id == null) return MapEntry(-1, <dynamic>[]);
        final nodes = await _loadEdgeNodes(id);
        return MapEntry(id, nodes);
      }).toList();
      final entries = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _edgeNodesByRestaurant = {
          for (final e in entries)
            if (e.key != -1) e.key: e.value,
        };
        _fleetLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _edgeNodesByRestaurant = {};
        _fleetLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _restaurants.where((r) => r['isActive'] == true).length;
    final demoCount = _restaurants
        .where((r) => r['subscriptionStatus'] == 'DEMO')
        .length;
    final fleet = _buildFleetHealthSummary();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Superadmin Paneli',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_username.isNotEmpty)
              Text(
                _fullName?.isNotEmpty == true
                    ? '$_fullName · @$_username'
                    : '@$_username',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRestaurants,
          ),
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatChip(
                              label: 'Toplam Restoran',
                              value: _restaurants.length.toString(),
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatChip(
                              label: 'Aktif',
                              value: activeCount.toString(),
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatChip(
                              label: 'Demo',
                              value: demoCount.toString(),
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.hub_outlined,
                                    size: 18,
                                    color: Colors.indigo,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Fleet Health',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_fleetLoading)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _FleetMetricChip(
                                    label: 'Toplam Node',
                                    value: fleet.total.toString(),
                                    color: Colors.blueGrey,
                                  ),
                                  _FleetMetricChip(
                                    label: 'ONLINE',
                                    value: fleet.online.toString(),
                                    color: Colors.green,
                                  ),
                                  _FleetMetricChip(
                                    label: 'DEGRADED',
                                    value: fleet.degraded.toString(),
                                    color: Colors.orange,
                                  ),
                                  _FleetMetricChip(
                                    label: 'MAINTENANCE',
                                    value: fleet.maintenance.toString(),
                                    color: Colors.blueGrey,
                                  ),
                                  _FleetMetricChip(
                                    label: 'OFFLINE',
                                    value: fleet.offline.toString(),
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _restaurants.isEmpty
                      ? const Center(
                          child: Text(
                            'Henüz restoran yok',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRestaurants,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _restaurants.length,
                            itemBuilder: (ctx, i) {
                              final r = _restaurants[i];
                              final rid = (r['id'] as num?)?.toInt();
                              return _RestaurantCard(
                                restaurant: r,
                                edgeNodes: rid != null
                                    ? (_edgeNodesByRestaurant[rid] ?? const [])
                                    : const [],
                                onTap: () => _doImpersonate(context, r),
                                onEdit: () =>
                                    _showEditRestaurantDialog(context, r),
                                onStaff: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _StaffScreen(restaurant: r),
                                  ),
                                ).then((_) => _loadRestaurants()),
                                onSms: () => _showSmsDialog(context, r),
                                onToggleActive: () =>
                                    _toggleRestaurantActive(context, r),
                                onSubscription: () =>
                                    _showSubscriptionDialog(context, r),
                                onOperationLogs: () =>
                                    _showOperationLogsDialog(context, r),
                                onLicenseManagement: () =>
                                    _showLicenseManagementDialog(context, r),
                                onEdgeSettings: () =>
                                    _showEdgeSettingsDialog(context, r),
                                onDelete: () => _confirmDelete(context, r),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRestaurantDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Restoran Ekle'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── Restoran aktif/pasif toggle ───────────────────────────────────────────

  Future<void> _toggleRestaurantActive(BuildContext context, dynamic r) async {
    final isActive = r['isActive'] == true;
    try {
      await ApiClient.instance.post(
        '${ApiConstants.superadminRestaurants}/${r['id']}/active',
        data: {'active': !isActive},
      );
      _loadRestaurants();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Restoran düzenleme ────────────────────────────────────────────────────

  void _showEditRestaurantDialog(BuildContext context, dynamic r) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: r['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: r['phone'] as String? ?? '');
    final emailCtrl = TextEditingController(text: r['email'] as String? ?? '');
    final addressCtrl = TextEditingController(
      text: r['address'] as String? ?? '',
    );
    final ibanCtrl = TextEditingController();
    bool menuImagesEnabled = r['isMenuImagesEnabled'] == true;
    bool posDeviceEnabled = r['isPosDeviceEnabled'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text('Düzenle: ${r['name']}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Restoran Adı *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Restoran adı zorunludur';
                      }
                      if (v.trim().length < 2) {
                        return 'En az 2 karakter olmalıdır';
                      }
                      if (v.trim().length > 100) {
                        return 'En fazla 100 karakter olabilir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: '05XXXXXXXXX',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (v.length < 10) return 'En az 10 haneli olmalıdır';
                      if (!RegExp(r'^0[5-9]\d{9}$').hasMatch(v)) {
                        return 'Geçerli bir telefon numarası girin (05XX...)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(
                        r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
                      ).hasMatch(v)) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adres',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: ibanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'IBAN (güncellemek için girin)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                      hintText: 'TR...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Menü Resimleri Aktif'),
                    subtitle: const Text('Müşteriye ürün görsellerini göster'),
                    value: menuImagesEnabled,
                    onChanged: (v) =>
                        setLocalState(() => menuImagesEnabled = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('POS Cihaz Kullanımı Aktif'),
                    subtitle: const Text(
                      'Bu restoranda POS cihaz akışını etkinleştir',
                    ),
                    value: posDeviceEnabled,
                    onChanged: (v) => setLocalState(() => posDeviceEnabled = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ApiClient.instance.put(
                    '${ApiConstants.superadminRestaurants}/${r['id']}',
                    data: {
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                      'email': emailCtrl.text.isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                      'address': addressCtrl.text.isEmpty
                          ? null
                          : addressCtrl.text.trim(),
                      if (ibanCtrl.text.isNotEmpty)
                        'ibanNumber': ibanCtrl.text.trim(),
                      'isMenuImagesEnabled': menuImagesEnabled,
                      'isPosDeviceEnabled': posDeviceEnabled,
                    },
                  );
                  nav.pop();
                  _loadRestaurants();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Restoran güncellendi')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Impersonate ────────────────────────────────────────────────────────────

  Future<void> _doImpersonate(BuildContext context, dynamic r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.instance.post(
        '${ApiConstants.superadminRestaurants}/${r['id']}/impersonate',
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final token = data['token'] as String?;
      if (token == null) throw Exception('Token alınamadı');
      await LocalStorage.saveToken(token);
      final rid =
          (data['restaurantId'] as num?)?.toInt() ?? (r['id'] as num?)?.toInt();
      await LocalStorage.saveUserInfo(
        username: data['username'] as String? ?? _username,
        fullName: data['fullName'] as String? ?? _fullName,
        role: 'RESTAURANT_ADMIN',
        restaurantName:
            data['restaurantName'] as String? ?? r['name'] as String?,
        restaurantId: rid,
        isImpersonated: true,
        isMenuImagesEnabled: data['isMenuImagesEnabled'] == true,
        isPosDeviceEnabled: data['isPosDeviceEnabled'] == true,
      );
      if (context.mounted) context.go('/admin');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Giriş yapılamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Abonelik yönetimi ──────────────────────────────────────────────────────

  void _showSubscriptionDialog(BuildContext context, dynamic r) {
    String selectedStatus = r['subscriptionStatus'] as String? ?? 'DEMO';
    DateTime? expiresAt;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Abonelik: ${r['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Abonelik Durumu',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Aktif')),
                  DropdownMenuItem(value: 'DEMO', child: Text('Demo')),
                  DropdownMenuItem(
                    value: 'EXPIRED',
                    child: Text('Süresi Doldu'),
                  ),
                  DropdownMenuItem(value: 'FROZEN', child: Text('Donduruldu')),
                ],
                onChanged: (val) {
                  if (val != null) setS(() => selectedStatus = val);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  expiresAt == null
                      ? 'Bitiş tarihi seç (opsiyonel)'
                      : 'Bitiş: ${expiresAt!.toLocal().toString().substring(0, 10)}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setS(() => expiresAt = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final params = <String, dynamic>{'status': selectedStatus};
                  if (expiresAt != null) {
                    params['expiresAt'] = expiresAt!
                        .toIso8601String()
                        .substring(0, 19);
                  }
                  await ApiClient.instance.dio.post(
                    '${ApiConstants.superadminRestaurants}/${r['id']}/subscription',
                    queryParameters: params,
                  );
                  nav.pop();
                  _loadRestaurants();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Abonelik güncellendi')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Silme onayı ────────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, dynamic r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restoranı Sil'),
        content: Text(
          '${r['name']} restoranını silmek istediğinize emin misiniz?\nTüm personel ve veriler silinecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.instance.delete(
                  '${ApiConstants.superadminRestaurants}/${r['id']}',
                );
                nav.pop();
                _loadRestaurants();
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ── SMS ────────────────────────────────────────────────────────────────────

  void _showSmsDialog(BuildContext context, dynamic r) {
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SMS: ${r['name']}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Mesaj *',
              border: OutlineInputBorder(),
              hintText: 'Mesajınızı buraya yazın...',
            ),
            maxLines: 4,
            maxLength: 160,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Mesaj boş olamaz';
              if (v.trim().length < 5) return 'En az 5 karakter olmalıdır';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.instance.post(
                  '${ApiConstants.superadminRestaurants}/${r['id']}/sms',
                  data: {'message': ctrl.text.trim()},
                );
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('SMS gönderildi')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  // ── Yeni restoran ekle ─────────────────────────────────────────────────────

  void _showAddRestaurantDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool menuImagesEnabled = false;
    bool posDeviceEnabled = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Yeni Restoran'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Restoran Adı *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Restoran adı zorunludur';
                      }
                      if (v.trim().length < 2) {
                        return 'En az 2 karakter olmalıdır';
                      }
                      if (v.trim().length > 100) {
                        return 'En fazla 100 karakter olabilir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: '05XXXXXXXXX',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (v.length < 10) return 'En az 10 haneli olmalıdır';
                      if (!RegExp(r'^0[5-9]\d{9}$').hasMatch(v)) {
                        return 'Geçerli bir telefon numarası girin (05XX...)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'ornek@restoran.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(
                        r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
                      ).hasMatch(v)) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Menü Resimleri Aktif'),
                    subtitle: const Text('Müşteriye ürün görsellerini göster'),
                    value: menuImagesEnabled,
                    onChanged: (v) =>
                        setLocalState(() => menuImagesEnabled = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('POS Cihaz Kullanımı Aktif'),
                    subtitle: const Text(
                      'Bu restoranda POS cihaz akışını etkinleştir',
                    ),
                    value: posDeviceEnabled,
                    onChanged: (v) => setLocalState(() => posDeviceEnabled = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ApiClient.instance.post(
                    ApiConstants.superadminRestaurants,
                    data: {
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                      'email': emailCtrl.text.isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                      'isMenuImagesEnabled': menuImagesEnabled,
                      'isPosDeviceEnabled': posDeviceEnabled,
                    },
                  );
                  nav.pop();
                  _loadRestaurants();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<dynamic>> _loadEdgeNodes(int restaurantId) async {
    final res = await ApiClient.instance.get(
      '${ApiConstants.superadminRestaurants}/$restaurantId/edge-nodes',
    );
    return List<dynamic>.from(res.data as List);
  }

  _FleetHealthSummary _buildFleetHealthSummary() {
    int online = 0;
    int degraded = 0;
    int maintenance = 0;
    int offline = 0;
    for (final nodes in _edgeNodesByRestaurant.values) {
      for (final node in nodes) {
        if (edgeNodeEffectiveOnline(node)) {
          online++;
          continue;
        }
        final status = (node['status'] as String?) ?? 'OFFLINE';
        switch (status) {
          case 'DEGRADED':
            degraded++;
            break;
          case 'MAINTENANCE':
            maintenance++;
            break;
          default:
            offline++;
        }
      }
    }
    return _FleetHealthSummary(
      total: online + degraded + maintenance + offline,
      online: online,
      degraded: degraded,
      maintenance: maintenance,
      offline: offline,
    );
  }

  Future<List<dynamic>> _loadFeatureFlags(int restaurantId) async {
    final res = await ApiClient.instance.get(
      '${ApiConstants.superadminRestaurants}/$restaurantId/feature-flags',
    );
    return List<dynamic>.from(res.data as List);
  }

  Future<List<dynamic>> _loadEnrollmentTokens(int restaurantId) async {
    final res = await ApiClient.instance.get(
      '${ApiConstants.superadminRestaurants}/$restaurantId/edge-enrollment-tokens',
    );
    return List<dynamic>.from(res.data as List);
  }

  Future<void> _showEdgeSettingsDialog(
    BuildContext context,
    dynamic restaurant,
  ) async {
    final restaurantId = (restaurant['id'] as num).toInt();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final results = await Future.wait([
        _loadEdgeNodes(restaurantId),
        _loadFeatureFlags(restaurantId),
        _loadEnrollmentTokens(restaurantId),
      ]);
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _EdgeSettingsSheet(
          restaurantId: restaurantId,
          restaurantName: restaurant['name'] as String? ?? 'Restoran',
          initialEdgeNodes: results[0],
          initialFeatureFlags: results[1],
          initialEnrollmentTokens: results[2],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Edge ayarları yüklenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showOperationLogsDialog(
    BuildContext context,
    dynamic restaurant,
  ) async {
    final restaurantId = (restaurant['id'] as num).toInt();
    await showDialog(
      context: context,
      builder: (_) => _OperationLogDialog(
        restaurantId: restaurantId,
        restaurantName: restaurant['name'] as String? ?? 'Restoran',
      ),
    );
  }

  Future<void> _showLicenseManagementDialog(
    BuildContext context,
    dynamic restaurant,
  ) async {
    final restaurantId = (restaurant['id'] as num).toInt();
    final messenger = ScaffoldMessenger.of(context);
    String selectedTemplate = 'BASIC';
    bool loading = true;
    Map<String, bool> previewFlags = {
      'POS': false,
      'BILL_PRINTING': false,
      'TABLE_PAYMENT': false,
      'MENU_IMAGES': false,
      'CUSTOMER_SPLIT_BILL': false,
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> loadFlags() async {
            try {
              final items = await _loadFeatureFlags(restaurantId);
              final nextFlags = {...previewFlags};
              for (final item in items) {
                final code = item['featureCode'] as String?;
                if (code != null && nextFlags.containsKey(code)) {
                  nextFlags[code] = item['enabled'] == true;
                }
              }
              if (ctx.mounted) {
                setS(() {
                  previewFlags = nextFlags;
                  loading = false;
                });
              }
            } catch (_) {
              if (ctx.mounted) {
                setS(() => loading = false);
              }
            }
          }

          if (loading) {
            loadFlags();
          }

          return AlertDialog(
            title: Text('Lisans Yönetimi · ${restaurant['name']}'),
            content: SizedBox(
              width: 480,
              child: loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paket Şablonu',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedTemplate,
                          items: const [
                            DropdownMenuItem(
                              value: 'BASIC',
                              child: Text('Basic'),
                            ),
                            DropdownMenuItem(value: 'PRO', child: Text('Pro')),
                            DropdownMenuItem(
                              value: 'ENTERPRISE',
                              child: Text('Enterprise'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setS(() => selectedTemplate = v);
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Template',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Mevcut Lisanslı Özellikler',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: previewFlags.entries
                              .map(
                                (entry) => _Badge(
                                  label:
                                      '${entry.key} · ${entry.value ? 'AÇIK' : 'KAPALI'}',
                                  color: entry.value
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat'),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        try {
                          await ApiClient.instance.post(
                            '${ApiConstants.superadminRestaurants}/$restaurantId/feature-flags/template',
                            data: {'template': selectedTemplate},
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '$selectedTemplate lisans şablonu uygulandı',
                              ),
                            ),
                          );
                          _loadRestaurants();
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Lisans şablonu uygulanamadı: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('Şablonu Uygula'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _RestaurantCard
// ════════════════════════════════════════════════════════════════════════════

class _RestaurantCard extends StatelessWidget {
  final dynamic restaurant;
  final List<dynamic> edgeNodes;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStaff;
  final VoidCallback onSms;
  final VoidCallback onToggleActive;
  final VoidCallback onSubscription;
  final VoidCallback onOperationLogs;
  final VoidCallback onLicenseManagement;
  final VoidCallback onEdgeSettings;
  final VoidCallback onDelete;

  const _RestaurantCard({
    required this.restaurant,
    this.edgeNodes = const [],
    required this.onTap,
    required this.onEdit,
    required this.onStaff,
    required this.onSms,
    required this.onToggleActive,
    required this.onSubscription,
    required this.onOperationLogs,
    required this.onLicenseManagement,
    required this.onEdgeSettings,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final status = r['subscriptionStatus'] as String? ?? 'DEMO';
    final isActive = r['isActive'] == true;
    final menuImagesEnabled = r['isMenuImagesEnabled'] == true;
    final posDeviceEnabled = r['isPosDeviceEnabled'] == true;
    final staffCount = (r['staffCount'] as num?)?.toInt() ?? 0;
    final name = r['name'] as String? ?? '';
    final restaurantId = (r['id'] as num?)?.toInt();
    final statusColor = _subscriptionColor(status);

    // Subtitle: telefon ve/veya email varsa göster, yoksa sadece personel sayısı
    final info = [
      if (r['phone'] != null) r['phone'] as String,
      if (r['email'] != null && r['phone'] == null) r['email'] as String,
      '$staffCount personel',
      menuImagesEnabled ? 'Menü Resmi: Açık' : 'Menü Resmi: Kapalı',
      posDeviceEnabled ? 'POS: Açık' : 'POS: Kapalı',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Sol: avatar + aktif nokta göstergesi
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Orta: isim + alt bilgi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantId != null ? '$name  ·  #$restaurantId' : name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    EdgeNodesCloudStatusStrip(nodes: edgeNodes, compact: true),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Abonelik chip
              _Badge(label: _subscriptionLabel(status), color: statusColor),
              const SizedBox(width: 2),
              // Düzenle ikonu
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: Colors.deepPurple,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Düzenle',
                onPressed: onEdit,
              ),
              // Aktif/Pasif toggle ikonu
              IconButton(
                icon: Icon(
                  isActive ? Icons.toggle_on : Icons.toggle_off,
                  size: 22,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: isActive ? 'Pasif Yap' : 'Aktif Yap',
                onPressed: onToggleActive,
              ),
              // Diğer aksiyonlar popup
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onSelected: (val) {
                  switch (val) {
                    case 'staff':
                      onStaff();
                    case 'sms':
                      onSms();
                    case 'subscription':
                      onSubscription();
                    case 'operation_logs':
                      onOperationLogs();
                    case 'license':
                      onLicenseManagement();
                    case 'edge_settings':
                      onEdgeSettings();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'staff',
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, size: 16),
                        SizedBox(width: 10),
                        Text('Personel Yönetimi'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sms',
                    child: Row(
                      children: [
                        Icon(Icons.sms_outlined, size: 16, color: Colors.teal),
                        SizedBox(width: 10),
                        Text('SMS Gönder'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'subscription',
                    child: Row(
                      children: [
                        Icon(Icons.payment, size: 16, color: Colors.blue),
                        SizedBox(width: 10),
                        Text('Abonelik'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'operation_logs',
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: Colors.brown),
                        SizedBox(width: 10),
                        Text('Operasyon Logları'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'license',
                    child: Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined, size: 16),
                        SizedBox(width: 10),
                        Text('Lisans / Paket'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edge_settings',
                    child: Row(
                      children: [
                        Icon(
                          Icons.hub_outlined,
                          size: 16,
                          color: Colors.indigo,
                        ),
                        SizedBox(width: 10),
                        Text('Edge / Paket Ayarları'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Sil', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _subscriptionColor(String status) => switch (status) {
    'ACTIVE' => Colors.green,
    'DEMO' => Colors.orange,
    'EXPIRED' => Colors.red,
    'FROZEN' => Colors.blueGrey,
    _ => Colors.grey,
  };

  String _subscriptionLabel(String status) => switch (status) {
    'ACTIVE' => 'Aktif',
    'DEMO' => 'Demo',
    'EXPIRED' => 'Süresi Doldu',
    'FROZEN' => 'Donduruldu',
    _ => status,
  };
}

// ════════════════════════════════════════════════════════════════════════════
// _StaffScreen — personel listesi ve yönetimi
// ════════════════════════════════════════════════════════════════════════════

class _StaffScreen extends StatefulWidget {
  final dynamic restaurant;
  const _StaffScreen({required this.restaurant});

  @override
  State<_StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<_StaffScreen> {
  List<dynamic> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(
        '${ApiConstants.superadminRestaurants}/${widget.restaurant['id']}/staff',
      );
      setState(() {
        _staff = List<dynamic>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.restaurant['name'] ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Personel Yönetimi',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStaff),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _staff.isEmpty
          ? const Center(
              child: Text(
                'Henüz personel yok',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStaff,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _staff.length,
                itemBuilder: (ctx, i) {
                  final s = _staff[i];
                  return _StaffCard(
                    staff: s,
                    restaurantId: (widget.restaurant['id'] as num).toInt(),
                    onEdit: () => _showStaffFormDialog(context, s),
                    onRefresh: _loadStaff,
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffFormDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Personel Ekle'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── Personel ekleme / düzenleme formu ─────────────────────────────────────

  void _showStaffFormDialog(BuildContext context, [dynamic existing]) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController(
      text: existing?['username'] ?? '',
    );
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController(
      text: existing?['fullName'] ?? '',
    );
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    String selectedRole = existing?['role'] as String? ?? 'WAITER';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? 'Personel Düzenle' : 'Yeni Personel'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameCtrl,
                    enabled: !isEdit,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı Adı *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Kullanıcı adı zorunludur';
                      }
                      if (v.trim().length < 3) {
                        return 'En az 3 karakter olmalıdır';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEdit
                          ? 'Şifre (değiştirmek için doldurun)'
                          : 'Şifre *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    validator: (v) {
                      if (!isEdit && (v == null || v.isEmpty)) {
                        return 'Şifre zorunludur';
                      }
                      if (v != null && v.isNotEmpty && v.length < 6) {
                        return 'En az 6 karakter olmalıdır';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: fullNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(
                        r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$',
                      ).hasMatch(v)) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: '05XXXXXXXXX',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (v.length < 10) return 'En az 10 haneli olmalıdır';
                      if (!RegExp(r'^0[5-9]\d{9}$').hasMatch(v)) {
                        return 'Geçerli bir telefon numarası girin (05XX...)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rol *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'RESTAURANT_ADMIN',
                        child: Text('Restoran Yöneticisi'),
                      ),
                      DropdownMenuItem(
                        value: 'HEAD_WAITER',
                        child: Text('Baş Garson'),
                      ),
                      DropdownMenuItem(value: 'WAITER', child: Text('Garson')),
                      DropdownMenuItem(value: 'CHEF', child: Text('Şef')),
                      DropdownMenuItem(value: 'VALET', child: Text('Vale')),
                    ],
                    onChanged: (val) {
                      if (val != null) setS(() => selectedRole = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final restaurantId = widget.restaurant['id'];
                  final data = <String, dynamic>{
                    'username': usernameCtrl.text.trim(),
                    'role': selectedRole,
                    if (!isEdit || passwordCtrl.text.isNotEmpty)
                      'password': passwordCtrl.text,
                    if (fullNameCtrl.text.isNotEmpty)
                      'fullName': fullNameCtrl.text.trim(),
                    if (emailCtrl.text.isNotEmpty)
                      'email': emailCtrl.text.trim(),
                    if (phoneCtrl.text.isNotEmpty) 'phone': phoneCtrl.text,
                  };
                  if (isEdit) {
                    await ApiClient.instance.put(
                      '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${existing!['id']}',
                      data: data,
                    );
                  } else {
                    await ApiClient.instance.post(
                      '${ApiConstants.superadminRestaurants}/$restaurantId/staff',
                      data: data,
                    );
                  }
                  nav.pop();
                  _loadStaff();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _StaffCard
// ════════════════════════════════════════════════════════════════════════════

class _StaffCard extends StatelessWidget {
  final dynamic staff;
  final int restaurantId;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  const _StaffCard({
    required this.staff,
    required this.restaurantId,
    required this.onEdit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final s = staff;
    final isActive = s['isActive'] == true;
    final isOnLeave = s['isOnLeave'] == true;
    final role = s['role'] as String? ?? '';
    final displayName = (s['fullName'] as String?)?.isNotEmpty == true
        ? s['fullName'] as String
        : s['username'] as String? ?? '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _roleColor(role).withValues(alpha: 0.2),
              child: Text(
                displayName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: _roleColor(role),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${s['username'] ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Badge(label: _roleLabel(role), color: _roleColor(role)),
                      if (!isActive)
                        const _Badge(label: 'Pasif', color: Colors.red),
                      if (isOnLeave)
                        const _Badge(label: 'İzinde', color: Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Düzenle'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_active',
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.block : Icons.check_circle,
                        size: 18,
                        color: isActive ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Pasif Yap' : 'Aktif Yap'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_leave',
                  child: Row(
                    children: [
                      Icon(
                        isOnLeave ? Icons.work : Icons.beach_access,
                        size: 18,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      Text(isOnLeave ? 'İzni Kaldır' : 'İzne Gönder'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sil', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case 'edit':
          onEdit();
        case 'toggle_active':
          await ApiClient.instance.post(
            '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${staff['id']}/active',
            data: {'active': !(staff['isActive'] == true)},
          );
          onRefresh();
        case 'toggle_leave':
          final isOnLeave = staff['isOnLeave'] == true;
          if (isOnLeave) {
            await ApiClient.instance.post(
              '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${staff['id']}/leave',
              data: {'onLeave': false, 'reason': ''},
            );
            onRefresh();
          } else {
            _showLeaveDialog(context);
          }
        case 'delete':
          await ApiClient.instance.delete(
            '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${staff['id']}',
          );
          onRefresh();
          messenger.showSnackBar(
            const SnackBar(content: Text('Personel silindi')),
          );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showLeaveDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İzin Sebebi'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Sebep (opsiyonel)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.instance.post(
                  '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${staff['id']}/leave',
                  data: {'onLeave': true, 'reason': ctrl.text.trim()},
                );
                nav.pop();
                onRefresh();
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('İzne Gönder'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
    'RESTAURANT_ADMIN' => Colors.deepPurple,
    'HEAD_WAITER' => Colors.indigo,
    'WAITER' => Colors.blue,
    'CHEF' => Colors.orange,
    'VALET' => Colors.teal,
    _ => Colors.grey,
  };

  String _roleLabel(String role) => switch (role) {
    'RESTAURANT_ADMIN' => 'Admin',
    'HEAD_WAITER' => 'Baş Garson',
    'WAITER' => 'Garson',
    'CHEF' => 'Şef',
    'VALET' => 'Vale',
    _ => role,
  };
}

// ════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ════════════════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FleetMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FleetHealthSummary {
  final int total;
  final int online;
  final int degraded;
  final int maintenance;
  final int offline;

  const _FleetHealthSummary({
    required this.total,
    required this.online,
    required this.degraded,
    required this.maintenance,
    required this.offline,
  });
}

class _OperationLogDialog extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;

  const _OperationLogDialog({
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<_OperationLogDialog> createState() => _OperationLogDialogState();
}

class _OperationLogDialogState extends State<_OperationLogDialog> {
  List<dynamic> _logs = [];
  bool _loading = true;
  int _page = 0;
  int _totalPages = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get(
        ApiConstants.superadminAuditLogs,
        queryParameters: {
          'restaurantId': widget.restaurantId,
          'page': _page,
          'size': _pageSize,
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      setState(() {
        _logs = List<dynamic>.from(data['content'] as List? ?? const []);
        _totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _logs = [];
        _loading = false;
      });
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return parsed.toLocal().toString().replaceFirst('T', ' ').substring(0, 19);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Operasyon Logları · ${widget.restaurantName}'),
      content: SizedBox(
        width: 760,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
            ? const Center(child: Text('Log kaydı bulunamadı'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _logs.length,
                      separatorBuilder: (_, unused) =>
                          const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final log = _logs[index] as Map<String, dynamic>;
                        final actor = (log['actorName'] as String?) ?? '-';
                        final action = (log['action'] as String?) ?? '-';
                        final entityType = (log['entityType'] as String?) ?? '-';
                        final details = (log['details'] as String?) ?? '-';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long, size: 18),
                          title: Text(
                            '$action · $actor',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_formatDate(log['createdAt'] as String?)}\n$entityType · $details',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Sayfa ${_page + 1}/$_totalPages'),
                      const Spacer(),
                      IconButton(
                        onPressed: _page > 0
                            ? () {
                                setState(() => _page -= 1);
                                _loadLogs();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        onPressed: _page + 1 < _totalPages
                            ? () {
                                setState(() => _page += 1);
                                _loadLogs();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _loadLogs,
          child: const Text('Yenile'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _EdgeSettingsSheet extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;
  final List<dynamic> initialEdgeNodes;
  final List<dynamic> initialFeatureFlags;
  final List<dynamic> initialEnrollmentTokens;

  const _EdgeSettingsSheet({
    required this.restaurantId,
    required this.restaurantName,
    required this.initialEdgeNodes,
    required this.initialFeatureFlags,
    required this.initialEnrollmentTokens,
  });

  @override
  State<_EdgeSettingsSheet> createState() => _EdgeSettingsSheetState();
}

class _EdgeSettingsSheetState extends State<_EdgeSettingsSheet> {
  late List<dynamic> _edgeNodes;
  late Map<String, bool> _featureFlags;
  late List<dynamic> _enrollmentTokens;
  bool _saving = false;

  late final TextEditingController _claimTokenCtrl;
  late final TextEditingController _claimNodeNameCtrl;
  bool _claimBusy = false;
  String? _lastBridgeJwt;

  static const List<String> _allFeatureCodes = [
    'POS',
    'BILL_PRINTING',
    'TABLE_PAYMENT',
    'MENU_IMAGES',
    'CUSTOMER_SPLIT_BILL',
  ];

  @override
  void initState() {
    super.initState();
    _edgeNodes = List<dynamic>.from(widget.initialEdgeNodes);
    _featureFlags = {for (final code in _allFeatureCodes) code: false};
    _enrollmentTokens = List<dynamic>.from(widget.initialEnrollmentTokens);
    for (final item in widget.initialFeatureFlags) {
      final code = item['featureCode'] as String?;
      if (code != null) _featureFlags[code] = item['enabled'] == true;
    }
    _claimTokenCtrl = TextEditingController();
    _claimNodeNameCtrl = TextEditingController(
      text: 'edge-${widget.restaurantId}',
    );
  }

  @override
  void dispose() {
    _claimTokenCtrl.dispose();
    _claimNodeNameCtrl.dispose();
    super.dispose();
  }

  String? _readBridgeJwtFromClaimBody(Object? raw) {
    Object? v = raw;
    if (v is String) {
      final t = v.trim();
      if (t.startsWith('{') || t.startsWith('[')) {
        try {
          v = jsonDecode(t);
        } catch (_) {
          return null;
        }
      } else {
        return null;
      }
    }
    if (v is! Map) return null;
    final map = Map<String, dynamic>.from(v);
    for (final key in ['bridgeJwtToken', 'bridge_jwt_token']) {
      final o = map[key];
      if (o is String && o.isNotEmpty) return o;
    }
    final inner = map['data'];
    if (inner != null && inner != map) {
      return _readBridgeJwtFromClaimBody(inner);
    }
    return null;
  }

  Future<void> _claimEnrollmentAndFetchBridgeJwt() async {
    final messenger = ScaffoldMessenger.of(context);
    final token = _claimTokenCtrl.text.trim();
    final nodeName = _claimNodeNameCtrl.text.trim();
    if (token.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Önce yukarıdan ürettiğin enrollment kodunu yapıştır'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (nodeName.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Edge node adı boş olamaz'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _claimBusy = true;
      _lastBridgeJwt = null;
    });
    try {
      final res = await ApiClient.instance.post(
        ApiConstants.edgeEnrollmentClaim,
        data: <String, dynamic>{
          'token': token,
          'nodeName': nodeName,
          'deviceType': 'MINI_PC',
          'localIp': '127.0.0.1',
        },
      );
      if (!mounted) return;
      final jwt = _readBridgeJwtFromClaimBody(res.data);
      if (jwt == null || jwt.isEmpty) {
        final hint = res.data is Map
            ? (res.data as Map).keys.take(12).join(', ')
            : res.data.runtimeType.toString();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Yanıtta köprü anahtarı bulunamadı. Gelen alanlar (ilk 12): $hint. '
              'Cloud backend’i yeniden derleyip çalıştırdığından emin ol.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final nodesRes = await ApiClient.instance.get(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/edge-nodes',
      );
      final tokensRes = await ApiClient.instance.get(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/edge-enrollment-tokens',
      );
      if (!mounted) return;
      setState(() {
        _lastBridgeJwt = jwt;
        _edgeNodes = List<dynamic>.from(nodesRes.data as List);
        _enrollmentTokens = List<dynamic>.from(tokensRes.data as List);
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Köprü anahtarı hazır. Aşağıdan kopyalayıp edge tarafındaki .env.edge içinde EDGE_BRIDGE_JWT_TOKEN satırına yapıştır.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimBusy = false);
    }
  }

  Future<void> _saveFeatureFlag(String code, bool enabled) async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.post(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/feature-flags',
        data: {'featureCode': code, 'enabled': enabled},
      );
      if (!mounted) return;
      setState(() => _featureFlags[code] = enabled);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feature flag kaydedilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyPackageTemplate(String template) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      final res = await ApiClient.instance.post(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/feature-flags/template',
        data: {'template': template},
      );
      final items = List<dynamic>.from(res.data as List);
      final nextFlags = {for (final code in _allFeatureCodes) code: false};
      for (final item in items) {
        final code = item['featureCode'] as String?;
        if (code != null) {
          nextFlags[code] = item['enabled'] == true;
        }
      }
      if (!mounted) return;
      setState(() => _featureFlags = nextFlags);
      messenger.showSnackBar(
        SnackBar(content: Text('$template paketi uygulandı')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Paket uygulanamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addEdgeNode() async {
    final formKey = GlobalKey<FormState>();
    final nodeNameCtrl = TextEditingController();
    final localIpCtrl = TextEditingController();
    String deviceType = 'MINI_PC';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edge Node Ekle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nodeNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Node adı *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Node adı zorunlu'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: deviceType,
                  decoration: const InputDecoration(
                    labelText: 'Cihaz tipi',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'MINI_PC', child: Text('Mini PC')),
                    DropdownMenuItem(
                      value: 'EXISTING_HARDWARE',
                      child: Text('Mevcut Donanım'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setS(() => deviceType = v);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: localIpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Local IP (opsiyonel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final res = await ApiClient.instance.post(
                    '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/edge-nodes',
                    data: {
                      'nodeName': nodeNameCtrl.text.trim(),
                      'deviceType': deviceType,
                      'localIp': localIpCtrl.text.trim().isEmpty
                          ? null
                          : localIpCtrl.text.trim(),
                    },
                  );
                  if (!mounted) return;
                  setState(() => _edgeNodes.insert(0, res.data));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Edge node eklenemedi: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createEnrollmentToken({int ttlMinutes = 30}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.instance.post(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/edge-enrollment-tokens',
        data: {'ttlMinutes': ttlMinutes},
      );
      if (!mounted) return;
      setState(() => _enrollmentTokens.insert(0, res.data));
      messenger.showSnackBar(
        const SnackBar(content: Text('Enrollment token üretildi')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Enrollment token üretilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelEnrollmentToken(dynamic tokenItem) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.instance.post(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/edge-enrollment-tokens/${tokenItem['id']}/cancel',
      );
      if (!mounted) return;
      final updated = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        final idx = _enrollmentTokens.indexWhere(
          (t) => t['id'] == tokenItem['id'],
        );
        if (idx != -1) _enrollmentTokens[idx] = updated;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Token iptal edildi')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Token iptal edilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cleanupEnrollmentTokens() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.instance.post(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/edge-enrollment-tokens/cleanup',
      );
      final deletedCount = (res.data is Map && res.data['deletedCount'] is num)
          ? (res.data['deletedCount'] as num).toInt()
          : 0;

      final refreshed = await ApiClient.instance.get(
        '${ApiConstants.superadminRestaurants}/${widget.restaurantId}/edge-enrollment-tokens',
      );
      if (!mounted) return;
      setState(
        () => _enrollmentTokens = List<dynamic>.from(refreshed.data as List),
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Temizlik tamamlandı ($deletedCount kayıt)')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Token temizleme başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyTokenToClipboard(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Token panoya kopyalandı')));
  }

  Future<void> _showTokenDialog(String tokenValue) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enrollment Token'),
        content: SizedBox(
          width: 520,
          child: SelectableText(
            tokenValue,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () {
              _copyTokenToClipboard(tokenValue);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Kopyala'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEdgeNodeStatus(dynamic node, String status) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.instance.put(
        '${ApiConstants.superadminEdgeNodes}/${node['id']}',
        data: {
          'nodeName': node['nodeName'],
          'deviceType': node['deviceType'],
          'localIp': node['localIp'],
          'isActive': node['isActive'] == true,
          'status': status,
        },
      );
      if (!mounted) return;
      final updated = res.data as Map<String, dynamic>;
      setState(() {
        final idx = _edgeNodes.indexWhere((n) => n['id'] == node['id']);
        if (idx != -1) _edgeNodes[idx] = updated;
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Node durumu güncellenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteEdgeNode(dynamic node) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.delete(
        '${ApiConstants.superadminEdgeNodes}/${node['id']}',
      );
      if (!mounted) return;
      setState(() => _edgeNodes.removeWhere((n) => n['id'] == node['id']));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Node silinemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _featureLabel(String code) => switch (code) {
    'POS' => 'POS',
    'BILL_PRINTING' => 'Adisyon Yazdırma',
    'TABLE_PAYMENT' => 'Masada Ödeme',
    'MENU_IMAGES' => 'Menü Görselleri',
    'CUSTOMER_SPLIT_BILL' => 'Müşteri Hesap Bölme',
    _ => code,
  };

  Color _statusColor(String status) => switch (status) {
    'ONLINE' => Colors.green,
    'DEGRADED' => Colors.orange,
    'MAINTENANCE' => Colors.blueGrey,
    _ => Colors.redAccent,
  };

  bool _tokenNeverExpires(dynamic token) {
    final v = token['neverExpires'];
    if (v == true || v == 1) return true;
    final raw = token['expiresAt'];
    if (raw is String && raw.contains('9999')) return true;
    return false;
  }

  /// Cloud [expiresAt] UTC duvar saati; `Z`/`+00:00` yoksa [DateTime.tryParse] cihaz yereline düşer ve EXPIRED yanlış çıkar.
  DateTime? _parseExpiresAtUtc(dynamic raw) {
    if (raw == null) return null;
    if (raw is! String) return null;
    final s = raw.trim();
    if (s.contains('9999')) {
      return DateTime.utc(9999, 12, 31, 23, 59, 59);
    }
    final hasExplicitOffset = s.endsWith('Z') ||
        s.endsWith('+00:00') ||
        RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s);
    if (!hasExplicitOffset) {
      final naive = RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$',
      ).firstMatch(s);
      if (naive != null) {
        return DateTime.parse('${naive.group(0)}Z').toUtc();
      }
    }
    return DateTime.tryParse(s)?.toUtc();
  }

  Color _tokenStatusColor(dynamic token) {
    final isUsed = token['isUsed'] == true;
    if (isUsed) return Colors.blueGrey;
    if (_tokenNeverExpires(token)) return Colors.teal;
    final expiresAt = _parseExpiresAtUtc(token['expiresAt']);
    final isExpired =
        expiresAt != null && expiresAt.toUtc().isBefore(DateTime.now().toUtc());
    if (isExpired) return Colors.red;
    return Colors.green;
  }

  String _tokenStatusLabel(dynamic token) {
    final isUsed = token['isUsed'] == true;
    if (isUsed) return 'USED';
    if (_tokenNeverExpires(token)) return 'NEVER_EXPIRES';
    final expiresAt = _parseExpiresAtUtc(token['expiresAt']);
    final isExpired =
        expiresAt != null && expiresAt.toUtc().isBefore(DateTime.now().toUtc());
    if (isExpired) return 'EXPIRED';
    return 'ACTIVE';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.restaurantName} · Edge / Paket Ayarları',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Edge Node\'lar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addEdgeNode,
                    icon: const Icon(Icons.add),
                    label: const Text('Node Ekle'),
                  ),
                ],
              ),
              if (_edgeNodes.isEmpty)
                const Text(
                  'Henüz edge node yok',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ..._edgeNodes.map((node) {
                  final status = (node['status'] as String?) ?? 'OFFLINE';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.memory_outlined),
                    title: Text(node['nodeName'] as String? ?? 'Unnamed Node'),
                    subtitle: Text(
                      '${node['deviceType'] ?? 'UNKNOWN'}'
                      '${(node['localIp'] as String?)?.isNotEmpty == true ? ' · ${node['localIp']}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Badge(label: status, color: _statusColor(status)),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              await _deleteEdgeNode(node);
                              return;
                            }
                            await _updateEdgeNodeStatus(node, value);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'ONLINE',
                              child: Text('Durum: ONLINE'),
                            ),
                            PopupMenuItem(
                              value: 'DEGRADED',
                              child: Text('Durum: DEGRADED'),
                            ),
                            PopupMenuItem(
                              value: 'MAINTENANCE',
                              child: Text('Durum: MAINTENANCE'),
                            ),
                            PopupMenuItem(
                              value: 'OFFLINE',
                              child: Text('Durum: OFFLINE'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Node Sil'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 28),
              Row(
                children: [
                  const Text(
                    'Restoran Özellikleri',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _applyPackageTemplate('BASIC'),
                    child: const Text('Basic'),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _applyPackageTemplate('PRO'),
                    child: const Text('Pro'),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _applyPackageTemplate('ENTERPRISE'),
                    child: const Text('Enterprise'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._allFeatureCodes.map((code) {
                final enabled = _featureFlags[code] == true;
                return SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_featureLabel(code)),
                  value: enabled,
                  onChanged: _saving ? null : (v) => _saveFeatureFlag(code, v),
                );
              }),
              const Divider(height: 28),
              Row(
                children: [
                  const Text(
                    'Enrollment Tokenları',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _createEnrollmentToken(ttlMinutes: 10080),
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: const Text('1 haftalık token üret'),
                  ),
                  TextButton(
                    onPressed: _cleanupEnrollmentTokens,
                    child: const Text('Expired Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Köprü anahtarı (.env.edge)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Swagger gerekmez: kısa enrollment kodunu yapıştır, cloud uzun köprü anahtarını üretsin. Kod tek kullanımlıktır.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _claimTokenCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Enrollment kodu',
                          border: OutlineInputBorder(),
                          hintText: 'Paneldeki kısa kod',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _claimNodeNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Edge node adı',
                          border: OutlineInputBorder(),
                          hintText: 'ör. edge-001',
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _claimBusy ? null : _claimEnrollmentAndFetchBridgeJwt,
                        child: _claimBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Köprü anahtarını al'),
                      ),
                      if (_lastBridgeJwt != null) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'EDGE_BRIDGE_JWT_TOKEN',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _lastBridgeJwt!,
                          style: const TextStyle(fontSize: 12),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _lastBridgeJwt!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Panoya kopyalandı')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Kopyala'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_enrollmentTokens.isEmpty)
                const Text(
                  'Henüz enrollment token yok',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ..._enrollmentTokens.take(8).map((tokenItem) {
                  final tokenValue = tokenItem['token'] as String? ?? '-';
                  final statusLabel = _tokenStatusLabel(tokenItem);
                  final statusColor = _tokenStatusColor(tokenItem);
                  final isUsed = tokenItem['isUsed'] == true;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showTokenDialog(tokenValue),
                    leading: const Icon(Icons.key_outlined),
                    title: Text(
                      tokenValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'expiresAt(UTC): ${tokenItem['expiresAt'] ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Badge(label: statusLabel, color: statusColor),
                        IconButton(
                          tooltip: 'Kopyala',
                          onPressed: () => _copyTokenToClipboard(tokenValue),
                          icon: const Icon(Icons.copy, size: 18),
                        ),
                        if (!isUsed)
                          IconButton(
                            tooltip: 'İptal Et',
                            onPressed: () => _cancelEnrollmentToken(tokenItem),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
