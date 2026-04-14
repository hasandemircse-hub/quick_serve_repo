import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/providers/auth_provider.dart';

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
  bool _loading = true;
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
      final res =
          await ApiClient.instance.get(ApiConstants.superadminRestaurants);
      setState(() {
        _restaurants = List<dynamic>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _restaurants.where((r) => r['isActive'] == true).length;
    final demoCount =
        _restaurants.where((r) => r['subscriptionStatus'] == 'DEMO').length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Superadmin Paneli',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            if (_username.isNotEmpty)
              Text(
                _fullName?.isNotEmpty == true
                    ? '$_fullName · @$_username'
                    : '@$_username',
                style: const TextStyle(
                    fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadRestaurants),
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
                  child: Row(
                    children: [
                      Expanded(
                          child: _StatChip(
                              label: 'Toplam Restoran',
                              value: _restaurants.length.toString(),
                              color: Colors.blue)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _StatChip(
                              label: 'Aktif',
                              value: activeCount.toString(),
                              color: Colors.green)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _StatChip(
                              label: 'Demo',
                              value: demoCount.toString(),
                              color: Colors.orange)),
                    ],
                  ),
                ),
                Expanded(
                  child: _restaurants.isEmpty
                      ? const Center(
                          child: Text('Henüz restoran yok',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRestaurants,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _restaurants.length,
                            itemBuilder: (ctx, i) {
                              final r = _restaurants[i];
                              return _RestaurantCard(
                                restaurant: r,
                                onTap: () => _doImpersonate(context, r),
                                onEdit: () =>
                                    _showEditRestaurantDialog(context, r),
                                onStaff: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _StaffScreen(restaurant: r),
                                  ),
                                ).then((_) => _loadRestaurants()),
                                onSms: () => _showSmsDialog(context, r),
                                onToggleActive: () =>
                                    _toggleRestaurantActive(context, r),
                                onSubscription: () =>
                                    _showSubscriptionDialog(context, r),
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
          data: {'active': !isActive});
      _loadRestaurants();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Restoran düzenleme ────────────────────────────────────────────────────

  void _showEditRestaurantDialog(BuildContext context, dynamic r) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: r['name'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: r['phone'] as String? ?? '');
    final emailCtrl =
        TextEditingController(text: r['email'] as String? ?? '');
    final addressCtrl =
        TextEditingController(text: r['address'] as String? ?? '');
    final ibanCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                    if (v.trim().length < 2) return 'En az 2 karakter olmalıdır';
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
                    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v)) {
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
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
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
                    'phone':
                        phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                    'email': emailCtrl.text.isEmpty
                        ? null
                        : emailCtrl.text.trim(),
                    'address': addressCtrl.text.isEmpty
                        ? null
                        : addressCtrl.text.trim(),
                    if (ibanCtrl.text.isNotEmpty)
                      'ibanNumber': ibanCtrl.text.trim(),
                  },
                );
                nav.pop();
                _loadRestaurants();
                messenger.showSnackBar(
                    const SnackBar(content: Text('Restoran güncellendi')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ── Impersonate ────────────────────────────────────────────────────────────

  Future<void> _doImpersonate(BuildContext context, dynamic r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiClient.instance.post(
          '${ApiConstants.superadminRestaurants}/${r['id']}/impersonate');
      final token = res.data['token'] as String?;
      if (token == null) throw Exception('Token alınamadı');
      await LocalStorage.saveToken(token);
      await LocalStorage.saveUserInfo(
        username: _username,
        fullName: _fullName,
        role: 'RESTAURANT_ADMIN',
        restaurantName: r['name'] as String?,
        isImpersonated: true,
      );
      if (context.mounted) context.go('/admin');
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Giriş yapılamadı: $e'),
        backgroundColor: Colors.red,
      ));
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
                      value: 'EXPIRED', child: Text('Süresi Doldu')),
                  DropdownMenuItem(
                      value: 'FROZEN', child: Text('Donduruldu')),
                ],
                onChanged: (val) {
                  if (val != null) setS(() => selectedStatus = val);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(expiresAt == null
                    ? 'Bitiş tarihi seç (opsiyonel)'
                    : 'Bitiş: ${expiresAt!.toLocal().toString().substring(0, 10)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setS(() => expiresAt = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final params = <String, dynamic>{'status': selectedStatus};
                  if (expiresAt != null) {
                    params['expiresAt'] =
                        expiresAt!.toIso8601String().substring(0, 19);
                  }
                  await ApiClient.instance.dio.post(
                      '${ApiConstants.superadminRestaurants}/${r['id']}/subscription',
                      queryParameters: params);
                  nav.pop();
                  _loadRestaurants();
                  messenger.showSnackBar(
                      const SnackBar(content: Text('Abonelik güncellendi')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red));
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
            '${r['name']} restoranını silmek istediğinize emin misiniz?\nTüm personel ve veriler silinecektir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.instance.delete(
                    '${ApiConstants.superadminRestaurants}/${r['id']}');
                nav.pop();
                _loadRestaurants();
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red));
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
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.instance.post(
                    '${ApiConstants.superadminRestaurants}/${r['id']}/sms',
                    data: {'message': ctrl.text.trim()});
                nav.pop();
                messenger
                    .showSnackBar(const SnackBar(content: Text('SMS gönderildi')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red));
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                    if (v.trim().length < 2) return 'En az 2 karakter olmalıdır';
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
                    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v)) {
                      return 'Geçerli bir e-posta adresi girin';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.instance
                    .post(ApiConstants.superadminRestaurants, data: {
                  'name': nameCtrl.text.trim(),
                  'phone':
                      phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                  'email': emailCtrl.text.isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                });
                nav.pop();
                _loadRestaurants();
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _RestaurantCard
// ════════════════════════════════════════════════════════════════════════════

class _RestaurantCard extends StatelessWidget {
  final dynamic restaurant;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStaff;
  final VoidCallback onSms;
  final VoidCallback onToggleActive;
  final VoidCallback onSubscription;
  final VoidCallback onDelete;

  const _RestaurantCard({
    required this.restaurant,
    required this.onTap,
    required this.onEdit,
    required this.onStaff,
    required this.onSms,
    required this.onToggleActive,
    required this.onSubscription,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final status = r['subscriptionStatus'] as String? ?? 'DEMO';
    final isActive = r['isActive'] == true;
    final staffCount = (r['staffCount'] as num?)?.toInt() ?? 0;
    final name = r['name'] as String? ?? '';
    final statusColor = _subscriptionColor(status);

    // Subtitle: telefon ve/veya email varsa göster, yoksa sadece personel sayısı
    final info = [
      if (r['phone'] != null) r['phone'] as String,
      if (r['email'] != null && r['phone'] == null) r['email'] as String,
      '$staffCount personel',
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
                          fontSize: 16),
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
                        border:
                            Border.all(color: Colors.white, width: 1.5),
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
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
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
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: isActive ? 'Pasif Yap' : 'Aktif Yap',
                onPressed: onToggleActive,
              ),
              // Diğer aksiyonlar popup
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18,
                    color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                onSelected: (val) {
                  switch (val) {
                    case 'staff':
                      onStaff();
                    case 'sms':
                      onSms();
                    case 'subscription':
                      onSubscription();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'staff',
                    child: Row(children: [
                      Icon(Icons.people_outline, size: 16),
                      SizedBox(width: 10),
                      Text('Personel Yönetimi'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'sms',
                    child: Row(children: [
                      Icon(Icons.sms_outlined,
                          size: 16, color: Colors.teal),
                      SizedBox(width: 10),
                      Text('SMS Gönder'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'subscription',
                    child: Row(children: [
                      Icon(Icons.payment, size: 16, color: Colors.blue),
                      SizedBox(width: 10),
                      Text('Abonelik'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Sil',
                          style: TextStyle(color: Colors.red)),
                    ]),
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
          '${ApiConstants.superadminRestaurants}/${widget.restaurant['id']}/staff');
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
            Text(widget.restaurant['name'] ?? '',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Personel Yönetimi',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                  child: Text('Henüz personel yok',
                      style: TextStyle(color: Colors.grey)),
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
                        restaurantId:
                            (widget.restaurant['id'] as num).toInt(),
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
    final usernameCtrl =
        TextEditingController(text: existing?['username'] ?? '');
    final passwordCtrl = TextEditingController();
    final fullNameCtrl =
        TextEditingController(text: existing?['fullName'] ?? '');
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
                      if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$')
                          .hasMatch(v)) {
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
                          child: Text('Restoran Yöneticisi')),
                      DropdownMenuItem(
                          value: 'HEAD_WAITER',
                          child: Text('Baş Garson')),
                      DropdownMenuItem(
                          value: 'WAITER', child: Text('Garson')),
                      DropdownMenuItem(value: 'CHEF', child: Text('Şef')),
                      DropdownMenuItem(
                          value: 'VALET', child: Text('Vale')),
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
                child: const Text('İptal')),
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
                    if (phoneCtrl.text.isNotEmpty)
                      'phone': phoneCtrl.text,
                  };
                  if (isEdit) {
                    await ApiClient.instance.put(
                        '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${existing!['id']}',
                        data: data);
                  } else {
                    await ApiClient.instance.post(
                        '${ApiConstants.superadminRestaurants}/$restaurantId/staff',
                        data: data);
                  }
                  nav.pop();
                  _loadStaff();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red));
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
    final displayName =
        (s['fullName'] as String?)?.isNotEmpty == true
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
                    color: _roleColor(role), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  Text('@${s['username'] ?? ''}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Badge(
                          label: _roleLabel(role),
                          color: _roleColor(role)),
                      if (!isActive)
                        const _Badge(label: 'Pasif', color: Colors.red),
                      if (isOnLeave)
                        const _Badge(
                            label: 'İzinde', color: Colors.purple),
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
                  child: Row(children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Düzenle'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle_active',
                  child: Row(children: [
                    Icon(isActive ? Icons.block : Icons.check_circle,
                        size: 18,
                        color: isActive ? Colors.orange : Colors.green),
                    const SizedBox(width: 8),
                    Text(isActive ? 'Pasif Yap' : 'Aktif Yap'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle_leave',
                  child: Row(children: [
                    Icon(
                        isOnLeave
                            ? Icons.work
                            : Icons.beach_access,
                        size: 18,
                        color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(isOnLeave ? 'İzni Kaldır' : 'İzne Gönder'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sil', style: TextStyle(color: Colors.red)),
                  ]),
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
              data: {'active': !(staff['isActive'] == true)});
          onRefresh();
        case 'toggle_leave':
          final isOnLeave = staff['isOnLeave'] == true;
          if (isOnLeave) {
            await ApiClient.instance.post(
                '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${staff['id']}/leave',
                data: {'onLeave': false, 'reason': ''});
            onRefresh();
          } else {
            _showLeaveDialog(context);
          }
        case 'delete':
          await ApiClient.instance.delete(
              '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${staff['id']}');
          onRefresh();
          messenger.showSnackBar(
              const SnackBar(content: Text('Personel silindi')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Hata: $e'), backgroundColor: Colors.red));
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
              child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiClient.instance.post(
                    '${ApiConstants.superadminRestaurants}/$restaurantId/staff/${staff['id']}/leave',
                    data: {
                      'onLeave': true,
                      'reason': ctrl.text.trim(),
                    });
                nav.pop();
                onRefresh();
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red));
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
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
