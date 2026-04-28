import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/providers/auth_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _tables = [];
  List<dynamic> _tableGroups = [];
  List<dynamic> _staff = [];
  List<dynamic> _menuItems = [];
  List<dynamic> _categories = [];
  bool _loading = true;

  String _username = '';
  String? _fullName;
  String? _restaurantName;
  bool _isImpersonated = false;

  final List<Tab> _tabs = const [
    Tab(icon: Icon(Icons.table_restaurant), text: 'Masalar'),
    Tab(icon: Icon(Icons.restaurant_menu), text: 'Menü'),
    Tab(icon: Icon(Icons.people), text: 'Personel'),
    Tab(icon: Icon(Icons.bar_chart), text: 'Raporlar'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _tabs.length, initialIndex: 2, vsync: this);
    _loadData(showLoading: true);
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final info = await LocalStorage.getUserInfo();
    if (!mounted) return;
    setState(() {
      _username = info['username'] as String? ?? '';
      _fullName = info['fullName'] as String?;
      _restaurantName = info['restaurantName'] as String?;
      _isImpersonated = info['isImpersonated'] as bool? ?? false;
    });
  }

  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get(ApiConstants.adminTables),
        ApiClient.instance.get(ApiConstants.adminStaff),
        ApiClient.instance.get(ApiConstants.adminMenuItems),
        ApiClient.instance.get(ApiConstants.adminMenuCategories),
        ApiClient.instance.get(ApiConstants.adminTableGroups),
      ]);
      setState(() {
        _tables = List<dynamic>.from(results[0].data);
        _staff = List<dynamic>.from(results[1].data);
        _menuItems = List<dynamic>.from(results[2].data);
        _categories = List<dynamic>.from(results[3].data);
        _tableGroups = List<dynamic>.from(results[4].data);
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
              _restaurantName?.isNotEmpty == true
                  ? _restaurantName!
                  : 'Admin Paneli',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_isImpersonated)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('SUPERADMIN',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'olarak yönetiyorsunuz',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[100]),
                  ),
                ],
              )
            else if (_username.isNotEmpty)
              Text(
                _fullName?.isNotEmpty == true
                    ? '$_fullName · @$_username'
                    : '@$_username',
                style: const TextStyle(
                    fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadData(showLoading: true)),
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
        bottom: TabBar(controller: _tabController, tabs: _tabs),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _TablesView(
                    tables: _tables,
                    groups: _tableGroups,
                    onRefresh: () => _loadData()),
                _MenuView(
                    items: _menuItems,
                    categories: _categories,
                    onRefresh: () => _loadData()),
                _StaffView(
                    staff: _staff,
                    onRefresh: () => _loadData(),
                    currentUsername:
                        ref.read(authProvider).state.username ?? '',
                    currentRole:
                        ref.read(authProvider).state.role ?? ''),
                _ReportsView(tables: _tables),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// ─── Masa Yönetimi ────────────────────────────────────────────────────────────

class _TablesView extends StatefulWidget {
  final List<dynamic> tables;
  final List<dynamic> groups;
  final VoidCallback onRefresh;
  const _TablesView({
    required this.tables,
    required this.groups,
    required this.onRefresh,
  });

  @override
  State<_TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends State<_TablesView> {
  // null  → "Tüm Masalar"
  // -1    → "Gruplandırılmamış"
  // diğer → grup id'si (int)
  Object? _selection = const _AllTablesSentinel();

  static const Object _allTables = _AllTablesSentinel();
  static const Object _ungrouped = _UngroupedSentinel();

  List<dynamic> _localGroups = [];

  @override
  void initState() {
    super.initState();
    _localGroups = List.from(widget.groups);
  }

  @override
  void didUpdateWidget(covariant _TablesView old) {
    super.didUpdateWidget(old);
    if (widget.groups != old.groups) {
      _localGroups = List.from(widget.groups);
      // Seçili grup silindiyse "Tüm Masalar"a düş.
      if (_selection is int) {
        final id = _selection as int;
        if (!_localGroups.any((g) => g['id'] == id)) {
          _selection = _allTables;
        }
      }
    }
  }

  List<dynamic> _tablesForSelection() {
    if (_selection == _allTables) return widget.tables;
    if (_selection == _ungrouped) {
      return widget.tables.where((t) => t['tableGroupId'] == null).toList();
    }
    final id = _selection as int;
    return widget.tables.where((t) => t['tableGroupId'] == id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 210, child: _buildGroupPanel(context)),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _buildTablesPanel(context)),
      ],
    );
  }

  // ── Sol Panel: Grup Listesi ──────────────────────────────────────────────

  Widget _buildGroupPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Masa Grupları',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Grup Ekle',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showGroupDialog(context),
              ),
            ],
          ),
        ),
        // "Tüm Masalar" sabit girişi
        ListTile(
          dense: true,
          selected: _selection == _allTables,
          selectedTileColor:
              Theme.of(context).colorScheme.primaryContainer,
          leading: const Icon(Icons.grid_view, size: 18),
          title: Text('Tüm Masalar (${widget.tables.length})',
              style: const TextStyle(fontSize: 13)),
          onTap: () => setState(() => _selection = _allTables),
        ),
        // "Gruplandırılmamış" sabit girişi (sadece varsa)
        if (widget.tables.any((t) => t['tableGroupId'] == null))
          ListTile(
            dense: true,
            selected: _selection == _ungrouped,
            selectedTileColor:
                Theme.of(context).colorScheme.primaryContainer,
            leading: const Icon(Icons.help_outline, size: 18),
            title: Text(
              'Gruplandırılmamış '
              '(${widget.tables.where((t) => t['tableGroupId'] == null).length})',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () => setState(() => _selection = _ungrouped),
          ),
        const Divider(height: 1),
        Expanded(
          child: _localGroups.isEmpty
              ? const Center(
                  child: Text('Grup yok',
                      style: TextStyle(color: Colors.grey, fontSize: 12)))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.zero,
                  onReorder: _reorderGroups,
                  itemCount: _localGroups.length,
                  itemBuilder: (ctx, i) {
                    final g = _localGroups[i];
                    final id = g['id'];
                    final isSelected = _selection == id;
                    final count = widget.tables
                        .where((t) => t['tableGroupId'] == id)
                        .length;
                    return ListTile(
                      key: ValueKey(id),
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle,
                                size: 18, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.layers, size: 14),
                        ],
                      ),
                      title: Text(
                        '${g['name']} ($count)',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16),
                        padding: EdgeInsets.zero,
                        onSelected: (action) =>
                            _handleGroupAction(context, action, g),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'edit',
                              child: Text('Yeniden Adlandır')),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text('Sil',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                      onTap: () => setState(() => _selection = id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Sağ Panel: Seçili Grubun Masaları ────────────────────────────────────

  Widget _buildTablesPanel(BuildContext context) {
    final tables = _tablesForSelection();
    final occupied =
        tables.where((t) => t['status'] == 'OCCUPIED').length;
    final title = _selection == _allTables
        ? 'Tüm Masalar'
        : _selection == _ungrouped
            ? 'Gruplandırılmamış'
            : (_localGroups.firstWhere(
                    (g) => g['id'] == _selection,
                    orElse: () => {'name': ''})['name'] as String? ??
                '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('$occupied dolu / ${tables.length} toplam',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Masa Ekle'),
                style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                onPressed: () => _showAddTableDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: tables.isEmpty
              ? const Center(
                  child: Text('Bu grupta masa yok',
                      style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8),
                  itemCount: tables.length,
                  itemBuilder: (ctx, i) {
                    final table = tables[i];
                    final isOccupied = table['status'] == 'OCCUPIED';
                    return Card(
                      color: isOccupied
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      child: InkWell(
                        onTap: () => _showTableMenu(context, table),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_restaurant,
                                color: isOccupied
                                    ? Colors.orange
                                    : Colors.green,
                                size: 28),
                            Text('Masa ${table['tableNumber']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(isOccupied ? 'Dolu' : 'Boş',
                                style: TextStyle(
                                    color: isOccupied
                                        ? Colors.orange
                                        : Colors.green,
                                    fontSize: 11)),
                            if (table['capacity'] != null)
                              Text('${table['capacity']} kişi',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            if (_selection == _allTables &&
                                table['tableGroupName'] != null)
                              Text(table['tableGroupName'],
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.blueGrey)),
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

  // ── Grup CRUD ────────────────────────────────────────────────────────────

  void _handleGroupAction(BuildContext context, String action, dynamic g) {
    switch (action) {
      case 'edit':
        _showGroupDialog(context, existing: g);
      case 'delete':
        _confirmDeleteGroup(context, g);
    }
  }

  Future<void> _reorderGroups(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final g = _localGroups.removeAt(oldIndex);
      _localGroups.insert(newIndex, g);
    });
    final body = _localGroups
        .asMap()
        .entries
        .map((e) => {'id': e.value['id'], 'displayOrder': e.key})
        .toList();
    try {
      await ApiClient.instance
          .put(ApiConstants.adminTableGroupsReorder, data: body);
      widget.onRefresh();
    } catch (_) {
      widget.onRefresh();
    }
  }

  void _showGroupDialog(BuildContext context, {dynamic existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Grup Düzenle' : 'Yeni Masa Grubu'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Grup Adı *',
              hintText: 'örn: Salon, Teras, Bahçe',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.layers),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Grup adı zorunludur'
                : null,
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
                if (isEdit) {
                  await ApiClient.instance.put(
                    '${ApiConstants.adminTableGroups}/${existing['id']}',
                    data: {'name': nameCtrl.text.trim()},
                  );
                } else {
                  await ApiClient.instance.post(
                    ApiConstants.adminTableGroups,
                    data: {'name': nameCtrl.text.trim()},
                  );
                }
                nav.pop();
                widget.onRefresh();
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                    content: Text(apiErrorMessage(e)),
                    backgroundColor: Colors.red));
              }
            },
            child: Text(isEdit ? 'Güncelle' : 'Oluştur'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
      BuildContext context, dynamic g) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grubu Sil'),
        content: Text(
            '"${g['name']}" grubunu silmek istediğinizden emin misiniz?\n\n'
            'Bu gruba bağlı masalar silinmez, "Gruplandırılmamış" listesine düşer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.instance
          .delete('${ApiConstants.adminTableGroups}/${g['id']}');
      if (_selection == g['id']) {
        setState(() => _selection = _allTables);
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Masa CRUD ────────────────────────────────────────────────────────────

  void _showTableMenu(BuildContext context, dynamic table) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('QR Kodu Göster / Yazdır'),
            onTap: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (_) => _QrDialog(table: table),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.layers),
            title: const Text('Grubu Değiştir'),
            onTap: () {
              Navigator.pop(ctx);
              _showAssignGroupDialog(context, table);
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('QR Kodu Yenile'),
            onTap: () {
              Navigator.pop(ctx);
              _regenerateQr(context, table);
            },
          ),
          if (table['hasPreviousQr'] == true)
            ListTile(
              leading: const Icon(Icons.undo, color: Colors.blue),
              title: const Text('Önceki QR\'a Geri Dön',
                  style: TextStyle(color: Colors.blue)),
              subtitle: const Text(
                  'Son yenilemeyi geri alır',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _undoRegenerateQr(context, table);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Masayı Sil',
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              ApiClient.instance
                  .delete('${ApiConstants.adminTables}/${table['id']}')
                  .then((_) => widget.onRefresh());
            },
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateQr(BuildContext context, dynamic table) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance
          .post('${ApiConstants.adminTables}/${table['id']}/regenerate-qr');
      widget.onRefresh();
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Masa ${table['tableNumber']} için QR yenilendi'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'GERİ AL',
            onPressed: () async {
              try {
                await ApiClient.instance.post(
                    '${ApiConstants.adminTables}/${table['id']}/undo-regenerate-qr');
                widget.onRefresh();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text(apiErrorMessage(e)),
                  backgroundColor: Colors.red,
                ));
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(apiErrorMessage(e)),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _undoRegenerateQr(BuildContext context, dynamic table) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Önceki QR\'a Geri Dön'),
        content: Text(
            'Masa ${table['tableNumber']} için son yenileme geri alınacak. '
            'Yeni basılan QR geçersiz hale gelir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Geri Dön'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.instance.post(
          '${ApiConstants.adminTables}/${table['id']}/undo-regenerate-qr');
      widget.onRefresh();
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        content: Text('Masa ${table['tableNumber']} önceki QR\'a döndürüldü'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(apiErrorMessage(e)),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showAssignGroupDialog(BuildContext context, dynamic table) {
    Object? selected = table['tableGroupId'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Masa ${table['tableNumber']} → Grup'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<Object?>(
                  dense: true,
                  value: null,
                  // ignore: deprecated_member_use
                  groupValue: selected,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setS(() => selected = v),
                  title: const Text('Gruplandırılmamış'),
                ),
                ..._localGroups.map((g) => RadioListTile<Object?>(
                      dense: true,
                      value: g['id'],
                      // ignore: deprecated_member_use
                      groupValue: selected,
                      // ignore: deprecated_member_use
                      onChanged: (v) => setS(() => selected = v),
                      title: Text(g['name'] as String? ?? ''),
                    )),
              ],
            ),
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
                  await ApiClient.instance.put(
                    '${ApiConstants.adminTables}/${table['id']}',
                    data: {
                      'tableNumber': table['tableNumber'],
                      'capacity': table['capacity'],
                      'tableGroupId': selected,
                    },
                  );
                  nav.pop();
                  widget.onRefresh();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                      content: Text(apiErrorMessage(e)),
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

  void _showAddTableDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final tableNumberCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '4');
    // Kullanıcı bir grup seçmişse o grupla başlasın.
    Object? selectedGroupId =
        _selection is int ? _selection : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Yeni Masa'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: tableNumberCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Masa Numarası *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.table_restaurant),
                      hintText: 'örn: 1, 2, A1',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(10),
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9]')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Masa numarası zorunludur';
                      }
                      if (v.trim().length > 10) {
                        return 'En fazla 10 karakter olabilir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: capacityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kapasite (Kişi Sayısı) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people_outline),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Kapasite zorunludur';
                      }
                      final n = int.tryParse(v);
                      if (n == null) return 'Geçerli bir sayı girin';
                      if (n < 1) return 'En az 1 kişi olmalıdır';
                      if (n > 50) return 'En fazla 50 kişi olabilir';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Object?>(
                    initialValue: selectedGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Grup',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.layers),
                    ),
                    items: [
                      const DropdownMenuItem<Object?>(
                          value: null, child: Text('Gruplandırılmamış')),
                      ..._localGroups.map((g) => DropdownMenuItem<Object?>(
                            value: g['id'],
                            child: Text(g['name'] as String? ?? ''),
                          )),
                    ],
                    onChanged: (val) =>
                        setS(() => selectedGroupId = val),
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
                  await ApiClient.instance.post(ApiConstants.adminTables,
                      data: {
                        'tableNumber': tableNumberCtrl.text.trim(),
                        'capacity': int.parse(capacityCtrl.text),
                        'tableGroupId': selectedGroupId,
                      });
                  nav.pop();
                  widget.onRefresh();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text(apiErrorMessage(e)),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllTablesSentinel {
  const _AllTablesSentinel();
}

class _UngroupedSentinel {
  const _UngroupedSentinel();
}

// ─── Menü Yönetimi ────────────────────────────────────────────────────────────

class _MenuView extends StatefulWidget {
  final List<dynamic> items;
  final List<dynamic> categories;
  final VoidCallback onRefresh;

  const _MenuView({
    required this.items,
    required this.categories,
    required this.onRefresh,
  });

  @override
  State<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<_MenuView> {
  dynamic _selectedCategory;
  dynamic _pendingSelectCategoryId;
  dynamic _pendingHighlightItemId;
  dynamic _highlightedItemId;
  List<dynamic> _localCategories = [];
  List<dynamic> _localItems = [];

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
  }

  @override
  void didUpdateWidget(_MenuView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sunucudan yeni kategori verisi gelince local listeyi senkronize et
    if (widget.categories != oldWidget.categories) {
      _localCategories = List.from(widget.categories);
    }

    if (_pendingSelectCategoryId != null) {
      final catId = _pendingSelectCategoryId;
      final itemId = _pendingHighlightItemId;
      _pendingSelectCategoryId = null;
      _pendingHighlightItemId = null;
      final found =
          _localCategories.where((c) => c['id'] == catId).toList();
      if (found.isNotEmpty) {
        _selectedCategory = found.first;
        _localItems = _itemsFor(_selectedCategory);
        if (itemId != null) {
          _highlightedItemId = itemId;
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _highlightedItemId = null);
          });
        }
      }
    } else if (_selectedCategory != null) {
      final id = _selectedCategory['id'];
      final found =
          _localCategories.where((c) => c['id'] == id).toList();
      _selectedCategory = found.isNotEmpty ? found.first : null;
    }

    // Sunucudan yeni ürün verisi gelince (refresh) local ürün listesini güncelle
    if (widget.items != oldWidget.items && _selectedCategory != null) {
      _localItems = _itemsFor(_selectedCategory);
    }
  }

  List<dynamic> _itemsFor(dynamic cat) => cat == null
      ? []
      : widget.items
          .where((item) => item['categoryId'] == cat['id'])
          .toList();

  void _selectCategory(dynamic cat) {
    setState(() {
      _selectedCategory = cat;
      _localItems = _itemsFor(cat);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 210,
          child: _buildCategoryPanel(context),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _buildItemsPanel(context)),
      ],
    );
  }

  // ── Sol Panel: Kategori Listesi ──────────────────────────────────────────

  Widget _buildCategoryPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kategoriler',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Kategori Ekle',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showCategoryDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: _localCategories.isEmpty
              ? const Center(
                  child: Text('Kategori yok',
                      style: TextStyle(color: Colors.grey, fontSize: 12)))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.zero,
                  onReorder: _reorderCategories,
                  itemCount: _localCategories.length,
                  itemBuilder: (ctx, i) {
                    final cat = _localCategories[i];
                    final isSelected =
                        _selectedCategory?['id'] == cat['id'];
                    final isActive = cat['isActive'] == true;
                    return ListTile(
                      key: ValueKey(cat['id']),
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle,
                                size: 18, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.category,
                              size: 14,
                              color: isActive ? null : Colors.grey),
                        ],
                      ),
                      title: Text(
                        cat['name'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive ? null : Colors.grey,
                          decoration: isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16),
                        padding: EdgeInsets.zero,
                        onSelected: (action) =>
                            _handleCategoryAction(context, action, cat),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit',
                              child: Text('Yeniden Adlandır')),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                                isActive ? 'Pasif Yap' : 'Aktif Yap'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Sil',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                      onTap: () => _selectCategory(cat),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Sağ Panel: Seçili Kategorinin Ürünleri ───────────────────────────────

  Widget _buildItemsPanel(BuildContext context) {
    if (_selectedCategory == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Sol panelden bir kategori seçin',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final items = _localItems;
    final catName = _selectedCategory['name'] as String? ?? '';
    final isCatActive = _selectedCategory['isActive'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(catName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Chip(
                      label: Text(isCatActive ? 'Aktif' : 'Pasif',
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: isCatActive
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      side: BorderSide.none,
                    ),
                    Text('${items.length} ürün',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ürün Ekle'),
                style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                onPressed: () => _showMenuItemDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('Bu kategoride henüz ürün yok',
                      style: TextStyle(color: Colors.grey)))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.zero,
                  onReorder: _reorderItems,
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final isItemActive = item['isActive'] == true;
                    final isHighlighted = item['id'] == _highlightedItemId;
                    return ListTile(
                      key: ValueKey(item['id']),
                      tileColor: isHighlighted
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.5)
                          : null,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle,
                                size: 20, color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          item['imageUrl'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(item['imageUrl'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.fastfood),
                        ],
                      ),
                      title: Text(item['name'] ?? ''),
                      subtitle: Text(
                        '${item['effectivePrice']} ₺'
                        '${isItemActive ? '' : '  •  Pasif'}',
                        style: TextStyle(
                            color: isItemActive ? null : Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isItemActive,
                            onChanged: (v) =>
                                _toggleItemActive(context, item, v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Düzenle',
                            onPressed: () =>
                                _showMenuItemDialog(context, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 18, color: Colors.red),
                            tooltip: 'Sil',
                            onPressed: () =>
                                _confirmDeleteItem(context, item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Sıralama ─────────────────────────────────────────────────────────────

  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final cat = _localCategories.removeAt(oldIndex);
      _localCategories.insert(newIndex, cat);
    });
    final body = _localCategories
        .asMap()
        .entries
        .map((e) => {'id': e.value['id'], 'displayOrder': e.key})
        .toList();
    try {
      await ApiClient.instance
          .put(ApiConstants.adminMenuCategoriesReorder, data: body);
      widget.onRefresh();
    } catch (_) {
      widget.onRefresh();
    }
  }

  Future<void> _reorderItems(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _localItems.removeAt(oldIndex);
      _localItems.insert(newIndex, item);
    });
    final body = _localItems
        .asMap()
        .entries
        .map((e) => {'id': e.value['id'], 'displayOrder': e.key})
        .toList();
    try {
      await ApiClient.instance
          .put(ApiConstants.adminMenuItemsReorder, data: body);
      widget.onRefresh();
    } catch (_) {
      widget.onRefresh();
    }
  }

  // ── Kategori İşlemleri ───────────────────────────────────────────────────

  void _handleCategoryAction(
      BuildContext context, String action, dynamic cat) {
    switch (action) {
      case 'edit':
        _showCategoryDialog(context, existing: cat);
      case 'toggle':
        _toggleCategoryActive(context, cat);
      case 'delete':
        _confirmDeleteCategory(context, cat);
    }
  }

  Future<void> _toggleCategoryActive(
      BuildContext context, dynamic cat) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.put(
        '${ApiConstants.adminMenuCategories}/${cat['id']}',
        data: {
          'name': cat['name'],
          'isActive': !(cat['isActive'] == true),
        },
      );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text(apiErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteCategory(
      BuildContext context, dynamic cat) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategoriyi Sil'),
        content: Text(
          '"${cat['name']}" kategorisini silmek istediğinizden emin misiniz?\n\n'
          'İçinde ürün bulunan kategori silinemez.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.instance
          .delete('${ApiConstants.adminMenuCategories}/${cat['id']}');
      if (_selectedCategory?['id'] == cat['id']) {
        setState(() => _selectedCategory = null);
      }
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCategoryDialog(BuildContext context, {dynamic existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Kategori Düzenle' : 'Yeni Kategori'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Kategori Adı *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Kategori adı zorunludur'
                : null,
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
                if (isEdit) {
                  await ApiClient.instance.put(
                    '${ApiConstants.adminMenuCategories}/${existing!['id']}',
                    data: {'name': nameCtrl.text.trim()},
                  );
                } else {
                  final response = await ApiClient.instance.post(
                    ApiConstants.adminMenuCategories,
                    data: {'name': nameCtrl.text.trim()},
                  );
                  _pendingSelectCategoryId = response.data['id'];
                }
                nav.pop();
                widget.onRefresh();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                      content: Text(apiErrorMessage(e)),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: Text(isEdit ? 'Güncelle' : 'Oluştur'),
          ),
        ],
      ),
    );
  }

  // ── Ürün İşlemleri ───────────────────────────────────────────────────────

  Future<void> _toggleItemActive(
      BuildContext context, dynamic item, bool newValue) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiClient.instance.put(
        '${ApiConstants.adminMenuItems}/${item['id']}',
        data: {
          'name': item['name'],
          'price': item['price'],
          'isActive': newValue,
        },
      );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text(apiErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteItem(
      BuildContext context, dynamic item) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text(
            '"${item['name']}" ürününü silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.instance
          .delete('${ApiConstants.adminMenuItems}/${item['id']}');
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text(apiErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMenuItemDialog(BuildContext context, [dynamic existing]) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? '${existing['price']}' : '');
    final descCtrl = TextEditingController(
        text: existing?['description'] as String? ?? '');
    final prepCtrl = TextEditingController(
      text: existing?['preparationTimeMinutes'] != null
          ? '${existing['preparationTimeMinutes']}'
          : '15',
    );
    // Seçili kategoriyi otomatik doldur
    dynamic selectedCategoryId =
        existing?['categoryId'] ?? _selectedCategory?['id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? 'Ürün Düzenle' : 'Yeni Ürün'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Ürün Adı *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.fastfood),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ürün adı zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fiyat (₺) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Fiyat zorunludur';
                      final n = double.tryParse(v);
                      if (n == null || n < 0) {
                        return 'Geçerli bir fiyat girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<dynamic>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Kategorisiz')),
                      ...widget.categories.map((c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['name'] as String? ?? ''),
                          )),
                    ],
                    onChanged: (val) =>
                        setS(() => selectedCategoryId = val),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: prepCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hazırlık Süresi (dk)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
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
                  final data = <String, dynamic>{
                    'name': nameCtrl.text.trim(),
                    'price': double.parse(priceCtrl.text),
                    'categoryId': selectedCategoryId,
                    if (descCtrl.text.isNotEmpty)
                      'description': descCtrl.text.trim(),
                    if (prepCtrl.text.isNotEmpty)
                      'preparationTimeMinutes': int.parse(prepCtrl.text),
                  };
                  dynamic response;
                  if (isEdit) {
                    response = await ApiClient.instance.put(
                        '${ApiConstants.adminMenuItems}/${existing!['id']}',
                        data: data);
                  } else {
                    response = await ApiClient.instance
                        .post(ApiConstants.adminMenuItems, data: data);
                  }
                  final catId = selectedCategoryId ??
                      response.data['categoryId'];
                  if (catId != null) _pendingSelectCategoryId = catId;
                  _pendingHighlightItemId = response.data['id'];
                  nav.pop();
                  widget.onRefresh();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                      content: Text(apiErrorMessage(e)),
                      backgroundColor: Colors.red));
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Personel Yönetimi ────────────────────────────────────────────────────────

class _StaffView extends StatelessWidget {
  final List<dynamic> staff;
  final VoidCallback onRefresh;
  final String currentUsername;
  final String currentRole;
  const _StaffView(
      {required this.staff,
      required this.onRefresh,
      required this.currentUsername,
      required this.currentRole});

  @override
  Widget build(BuildContext context) {
    final sorted = [...staff]..sort((a, b) {
        final rCmp = _roleOrder(a['role'] as String?)
            .compareTo(_roleOrder(b['role'] as String?));
        if (rCmp != 0) return rCmp;
        final aName = ((a['fullName'] as String?) ??
                (a['username'] as String?) ??
                '')
            .toLowerCase();
        final bName = ((b['fullName'] as String?) ??
                (b['username'] as String?) ??
                '')
            .toLowerCase();
        return aName.compareTo(bName);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Personel Ekle'),
                onPressed: () => _showStaffFormDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: sorted.isEmpty
              ? const Center(
                  child: Text('Henüz personel yok',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: sorted.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (ctx, i) {
                    final member = sorted[i];
                    final isLeave = member['isOnLeave'] == true;
                    final isActive = member['isActive'] == true;
                    final role = member['role'] as String?;
                    final fullName = member['fullName'] as String?;
                    final username =
                        member['username'] as String? ?? '';
                    final email = member['email'] as String?;
                    final phone = member['phone'] as String?;
                    final initial = ((fullName?.isNotEmpty == true
                                ? fullName!
                                : username)
                            .substring(0, 1))
                        .toUpperCase();
                    final roleColor = _roleColor(role);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: roleColor,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fullName?.isNotEmpty == true
                                              ? fullName!
                                              : username,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              roleColor.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: roleColor
                                                  .withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          _roleLabel(role),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: roleColor,
                                              fontWeight:
                                                  FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text('@$username',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                  if (email != null && email.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.email_outlined,
                                            size: 12,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(email,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  if (phone != null && phone.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.phone,
                                            size: 12,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(phone,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  if (!isActive || isLeave)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 4),
                                      child: Wrap(
                                        spacing: 4,
                                        children: [
                                          if (!isActive)
                                            const Chip(
                                              label: Text('Pasif',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.white)),
                                              backgroundColor:
                                                  Colors.grey,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: EdgeInsets.zero,
                                            ),
                                          if (isLeave)
                                            const Chip(
                                              label: Text('İzinli',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.white)),
                                              backgroundColor:
                                                  Colors.orange,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: EdgeInsets.zero,
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () =>
                                      _showStaffFormDialog(context, member),
                                ),
                                if (member['username'] != currentUsername)
                                  IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () => _showStaffActions(
                                        context, member, currentUsername),
                                  ),
                              ],
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

  int _roleOrder(String? role) => switch (role) {
        'RESTAURANT_ADMIN' => 0,
        'HEAD_WAITER' => 1,
        'CHEF' => 2,
        'WAITER' => 3,
        'VALET' => 4,
        _ => 5,
      };

  Color _roleColor(String? role) => switch (role) {
        'RESTAURANT_ADMIN' => Colors.deepPurple,
        'HEAD_WAITER' => Colors.blue,
        'CHEF' => Colors.orange,
        'WAITER' => Colors.teal,
        'VALET' => Colors.brown,
        _ => Colors.grey,
      };

  String _roleLabel(String? role) => switch (role) {
        'WAITER' => 'Garson',
        'HEAD_WAITER' => 'Baş Garson',
        'CHEF' => 'Aşçı',
        'VALET' => 'Vale',
        'RESTAURANT_ADMIN' => 'Restoran Admini',
        _ => role ?? '',
      };

  void _showStaffFormDialog(BuildContext context, [dynamic existing]) {
    final isEdit = existing != null;
    final isSelf =
        isEdit && (existing['username'] as String?) == currentUsername;
    final formKey = GlobalKey<FormState>();
    final usernameCtrl =
        TextEditingController(text: existing?['username'] as String? ?? '');
    final passwordCtrl = TextEditingController();
    final fullNameCtrl =
        TextEditingController(text: existing?['fullName'] as String? ?? '');
    final emailCtrl =
        TextEditingController(text: existing?['email'] as String? ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?['phone'] as String? ?? '');
    String selectedRole =
        existing?['role'] as String? ?? 'WAITER';

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
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                          text: newValue.text.toLowerCase(),
                        ),
                      ),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Kullanıcı adı zorunludur';
                      }
                      if (v.trim().length < 3) {
                        return 'En az 3 karakter olmalıdır';
                      }
                      if (v.trim() != v.trim().toLowerCase()) {
                        return 'Kullanıcı adı yalnızca küçük harf içerebilir';
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
                    items: [
                      if (currentRole == 'SUPERADMIN' ||
                          selectedRole == 'RESTAURANT_ADMIN')
                        const DropdownMenuItem(
                            value: 'RESTAURANT_ADMIN',
                            child: Text('Restoran Admini')),
                      const DropdownMenuItem(
                          value: 'HEAD_WAITER',
                          child: Text('Baş Garson')),
                      const DropdownMenuItem(
                          value: 'WAITER', child: Text('Garson')),
                      const DropdownMenuItem(
                          value: 'CHEF', child: Text('Aşçı')),
                      const DropdownMenuItem(
                          value: 'VALET', child: Text('Vale')),
                    ],
                    onChanged: (isSelf ||
                            (selectedRole == 'RESTAURANT_ADMIN' &&
                                currentRole != 'SUPERADMIN'))
                        ? null
                        : (val) {
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
                        '${ApiConstants.adminStaff}/${existing!['id']}',
                        data: data);
                  } else {
                    await ApiClient.instance
                        .post(ApiConstants.adminStaff, data: data);
                  }
                  nav.pop();
                  onRefresh();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                      content: Text(apiErrorMessage(e)),
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

  void _showStaffActions(
      BuildContext context, dynamic member, String currentUsername) {
    final isSelf = (member['username'] as String?) == currentUsername;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSelf)
            ListTile(
              leading: Icon(member['isOnLeave'] == true
                  ? Icons.work
                  : Icons.beach_access),
              title: Text(
                  member['isOnLeave'] == true ? 'İzni Kaldır' : 'İzne Çıkar'),
              onTap: () {
                Navigator.pop(ctx);
                ApiClient.instance
                    .post('${ApiConstants.adminStaff}/${member['id']}/leave',
                        data: {'onLeave': !(member['isOnLeave'] == true)})
                    .then((_) => onRefresh());
              },
            ),
          if (!isSelf)
            ListTile(
              leading: Icon(member['isActive'] == true
                  ? Icons.block
                  : Icons.check_circle),
              title: Text(
                  member['isActive'] == true ? 'Pasif Yap' : 'Aktif Yap'),
              onTap: () {
                Navigator.pop(ctx);
                ApiClient.instance
                    .post(
                        '${ApiConstants.adminStaff}/${member['id']}/active',
                        data: {'active': !(member['isActive'] == true)})
                    .then((_) => onRefresh());
              },
            ),
          if (!isSelf)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Sil', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                ApiClient.instance
                    .delete('${ApiConstants.adminStaff}/${member['id']}')
                    .then((_) => onRefresh());
              },
            ),
        ],
      ),
    );
  }
}

// ─── Raporlar ─────────────────────────────────────────────────────────────────

class _ReportsView extends StatelessWidget {
  final List<dynamic> tables;
  const _ReportsView({required this.tables});

  @override
  Widget build(BuildContext context) {
    final occupied = tables.where((t) => t['status'] == 'OCCUPIED').length;
    final total = tables.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _StatCard(
            title: 'Masa Doluluk',
            value: total > 0
                ? '${((occupied / total) * 100).toStringAsFixed(0)}%'
                : '0%',
            subtitle: '$occupied / $total masa dolu',
            icon: Icons.table_restaurant,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Detaylı raporlar'),
              subtitle: Text(
                  'Bugünkü ciro ve sipariş istatistikleri yakında eklenecek'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _QrDialog extends StatefulWidget {
  final dynamic table;
  const _QrDialog({required this.table});

  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<_QrDialog> {
  Uint8List? _qrBytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchQr();
  }

  Future<void> _fetchQr() async {
    try {
      final resp = await ApiClient.instance.dio.get(
        '${ApiConstants.adminTables}/${widget.table['id']}/qr',
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted) {
        setState(() {
          _qrBytes = Uint8List.fromList(resp.data as List<int>);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'QR kodu yüklenemedi';
          _loading = false;
        });
      }
    }
  }

  Future<void> _print() async {
    if (_qrBytes == null) return;
    final doc = pw.Document();
    final image = pw.MemoryImage(_qrBytes!);
    final tableLabel = 'Masa ${widget.table['tableNumber']}';
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(tableLabel,
                    style: pw.TextStyle(
                        fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 24),
                pw.Image(image, width: 280, height: 280),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final tableLabel = 'Masa ${widget.table['tableNumber']}';
    return AlertDialog(
      title: Text('QR Kodu — $tableLabel'),
      content: SizedBox(
        width: 280,
        height: 300,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Image.memory(_qrBytes!, fit: BoxFit.contain),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        if (_qrBytes != null)
          FilledButton.icon(
            onPressed: _print,
            icon: const Icon(Icons.print),
            label: const Text('Yazdır'),
          ),
      ],
    );
  }
}
