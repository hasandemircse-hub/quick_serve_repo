// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/customer_session_provider.dart';
import '../../../core/storage/local_storage.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  static const String _modeItems = 'ITEMS';
  static const String _modeSession = 'SESSION';
  String _selectedMethod = 'CASH';
  String _paymentMode = _modeItems;
  double _tip = 0;
  bool _loadingOrders = true;
  bool _paying = false;
  String? _sessionToken;
  Map<String, dynamic> _financialSummary = const {};
  List<dynamic> _payableItems = const [];
  List<dynamic> _payments = const [];
  Map<int, Map<String, dynamic>> _orderItemById = const {};
  final Set<String> _selectedUnitKeys = <String>{};
  final TextEditingController _contributionCtrl = TextEditingController();

  final List<Map<String, dynamic>> _methods = [
    {'key': 'CASH', 'label': 'Nakit', 'icon': Icons.money},
    {'key': 'CREDIT_CARD', 'label': 'Kredi Kartı', 'icon': Icons.credit_card},
    {'key': 'DEBIT_CARD', 'label': 'Banka Kartı', 'icon': Icons.credit_card_outlined},
    {'key': 'OTHER', 'label': 'Diğer', 'icon': Icons.more_horiz},
  ];

  final List<int> _tipPercents = [0, 5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _contributionCtrl.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    _sessionToken = await LocalStorage.getSessionToken();
    if (_sessionToken == null) {
      if (mounted) context.go('/scan');
      return;
    }
    try {
      final results = await Future.wait([
        ApiClient.instance.get(ApiConstants.customerOrders, sessionToken: _sessionToken),
        ApiClient.instance.get(ApiConstants.customerPayments, sessionToken: _sessionToken),
        ApiClient.instance.get(ApiConstants.customerPaymentsFinancialSummary, sessionToken: _sessionToken),
        ApiClient.instance.get(ApiConstants.customerPaymentsPayableItems, sessionToken: _sessionToken),
      ]);
      final orders = List<dynamic>.from(results[0].data as List? ?? const []);
      final payments = List<dynamic>.from(results[1].data as List? ?? const []);
      final summary = Map<String, dynamic>.from(results[2].data as Map? ?? const {});
      final payableItems = List<dynamic>.from(results[3].data as List? ?? const []);
      await ref.read(customerSessionProvider.notifier).setSession(_sessionToken!);
      setState(() {
        _payments = payments;
        _financialSummary = summary;
        _payableItems = payableItems;
        _orderItemById = _indexOrderItemsById(orders);
        _selectedUnitKeys
          ..clear()
          ..addAll(_payableUnitRows(payableItems).map((r) => r['key'] as String));
        _contributionCtrl.text = ((summary['outstandingAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
        _loadingOrders = false;
      });
      // İlk yükte provider verisini de senkronlamak için REST sonucunu bir kez refresh et.
      if (orders.isNotEmpty) {
        await ref.read(customerSessionProvider.notifier).refreshOrders();
      }
    } catch (_) {
      setState(() => _loadingOrders = false);
    }
  }

  double _computeTotal(List<dynamic> orders) {
    final fromSummary = (_financialSummary['sessionTotal'] as num?)?.toDouble();
    if (fromSummary != null) return fromSummary;
    return orders.where((o) => o['status'] != 'CANCELLED').fold<double>(
        0, (s, o) => s + ((o['totalAmount'] as num?)?.toDouble() ?? 0));
  }

  double _tipAmount(double total) => total * _tip / 100;
  double _selectedItemsTotal() {
    return _payableUnitRows(_payableItems).fold<double>(0, (s, row) {
      final key = row['key'] as String;
      if (!_selectedUnitKeys.contains(key)) return s;
      return s + ((row['amount'] as num?)?.toDouble() ?? 0);
    });
  }
  double _sessionContributionAmount() =>
      double.tryParse(_contributionCtrl.text.replaceAll(',', '.')) ?? 0;
  double _grandTotal(double total) {
    final base = _paymentMode == _modeItems ? _selectedItemsTotal() : _sessionContributionAmount();
    return base + _tipAmount(base);
  }

  @override
  Widget build(BuildContext context) {
    final sessionClosedMessage =
        ref.watch(customerSessionProvider.select((s) => s.sessionClosedMessage));
    if (sessionClosedMessage != null && sessionClosedMessage.isNotEmpty) {
      _handleSessionClosed(sessionClosedMessage);
    }
    final orders = ref.watch(customerSessionProvider.select((s) => s.orders));
    final total = _computeTotal(orders);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(title: const Text('Ödeme')),
      body: _loadingOrders
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(total),
                  const SizedBox(height: 16),
                  _buildPaymentModeSelector(),
                  const SizedBox(height: 12),
                  _buildAllocationSection(),
                  const SizedBox(height: 16),
                  _buildTipSection(),
                  const SizedBox(height: 16),
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 16),
                  _buildSplitButton(total),
                  const SizedBox(height: 24),
                  _buildPayButton(total),
                  const SizedBox(height: 16),
                  _buildPaymentHistoryCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ── Tutar Özeti ─────────────────────────────────────────────────────────────

  Widget _buildSummaryCard(double total) {
    final baseAmount =
        _paymentMode == _modeItems ? _selectedItemsTotal() : _sessionContributionAmount();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Masa Toplamı', '₺${total.toStringAsFixed(2)}', null),
            const SizedBox(height: 6),
            _summaryRow(
              _paymentMode == _modeItems ? 'Seçili Ürünler' : 'Katkı Tutarı',
              '₺${baseAmount.toStringAsFixed(2)}',
              Theme.of(context).colorScheme.primary,
              bold: true,
            ),
            if (_tip > 0) ...[
              const SizedBox(height: 6),
              _summaryRow('Bahşiş (%${_tip.toInt()})',
                  '₺${_tipAmount(baseAmount).toStringAsFixed(2)}', Colors.green),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            _summaryRow(
              'Toplam',
              '₺${_grandTotal(baseAmount).toStringAsFixed(2)}',
              Theme.of(context).colorScheme.primary,
              bold: true,
              fontSize: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color? valueColor,
      {bool bold = false, double fontSize = 14}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: fontSize,
        color: valueColor);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: fontSize)),
        Text(value, style: style),
      ],
    );
  }

  // ── Sipariş Listesi ──────────────────────────────────────────────────────────

  // ignore: unused_element
  Widget _buildOrderList(List<dynamic> orders) {
    final active =
        orders.where((o) => o['status'] != 'CANCELLED').toList();
    if (active.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Sipariş bulunamadı')),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Siparişler',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          ...active.map((order) {
            final status = order['status'] as String? ?? '';
            final amount =
                (order['totalAmount'] as num?)?.toDouble() ?? 0;
            final items =
                List<dynamic>.from(order['items'] as List? ?? []);
            final statusLabel = _statusLabel(status);
            final statusColor = _statusColor(status);
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      Text('₺${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...items.map((item) {
                    final name =
                        item['menuItemName'] as String? ?? '';
                    final qty = item['quantity'] as int? ?? 1;
                    return Padding(
                      padding: const EdgeInsets.only(top: 2, left: 4),
                      child: Row(
                        children: [
                          Text('$qty×',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 16),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentModeSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: _modeItems, label: Text('Ürün Seç')),
        ButtonSegment(value: _modeSession, label: Text('Masaya Katkı')),
      ],
      selected: {_paymentMode},
      onSelectionChanged: (set) => setState(() => _paymentMode = set.first),
    );
  }

  Widget _buildAllocationSection() {
    if (_paymentMode == _modeSession) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masaya katkı tutarı', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _contributionCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Tutar (TRY)',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      );
    }

    if (_payableItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Ödenebilir ürün kalemi yok'),
        ),
      );
    }
    final unitRows = _payableUnitRows(_payableItems);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          const ListTile(
            title: Text('Ödenecek Ürünler', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...unitRows.map((row) {
            final key = row['key'] as String;
            final name = (row['name'] ?? '').toString();
            final amount = (row['amount'] as num?)?.toDouble() ?? 0;
            final unitNo = (row['unitNo'] as num?)?.toInt() ?? 1;
            final selected = _selectedUnitKeys.contains(key);
            return CheckboxListTile(
              value: selected,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selectedUnitKeys.add(key);
                } else {
                  _selectedUnitKeys.remove(key);
                }
              }),
              title: Text('$name ($unitNo)'),
              subtitle: Text('₺${amount.toStringAsFixed(2)}'),
            );
          }),
        ],
      ),
    );
  }

  // ── Bahşiş ──────────────────────────────────────────────────────────────────

  Widget _buildTipSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bahşiş',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _tipPercents.map((t) {
                final selected = _tip == t.toDouble();
                return GestureDetector(
                  onTap: () => setState(() => _tip = t.toDouble()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 54,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t == 0 ? 'Yok' : '%$t',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ödeme Yöntemi ────────────────────────────────────────────────────────────

  Widget _buildPaymentMethodSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('Ödeme Yöntemi',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          ..._methods.map((m) => RadioListTile<String>(
                value: m['key'] as String,
                groupValue: _selectedMethod,
                title: Text(m['label'] as String),
                secondary: Icon(m['icon'] as IconData),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMethod = v);
                },
              )),
        ],
      ),
    );
  }

  // ── Hesabı Böl ───────────────────────────────────────────────────────────────

  Widget _buildSplitButton(double total) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.people_outline),
        label: const Text('Hesabı Böl'),
        onPressed: () => _showSplitDialog(context, total),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12)),
      ),
    );
  }

  Widget _buildPaymentHistoryCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text('Yapılan Ödemeler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          if (_payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Henüz ödeme yapılmadı'),
            )
          else
            ..._payments.map((p) => _paymentTile(Map<String, dynamic>.from(p as Map))),
        ],
      ),
    );
  }

  Widget _paymentTile(Map<String, dynamic> payment) {
    final method = (payment['method'] ?? '').toString();
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final tip = (payment['tipAmount'] as num?)?.toDouble() ?? 0;
    final status = (payment['status'] ?? '').toString();
    final createdAt = _formatDateTime((payment['createdAt'] ?? '').toString());
    final allocations = List<dynamic>.from(payment['allocations'] as List? ?? const []);
    final total = amount + tip;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(_paymentMethodLabel(method),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$createdAt • ${_paymentStatusLabel(status)}'),
      trailing: Text(
        '₺${total.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        _summaryRow('Ödeme Tutarı', '₺${amount.toStringAsFixed(2)}', null),
        if (tip > 0)
          _summaryRow('Bahşiş', '₺${tip.toStringAsFixed(2)}', Colors.green),
        if (allocations.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Dağıtım',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 4),
          ...allocations.map((a) {
            final item = Map<String, dynamic>.from(a as Map);
            final targetType = (item['targetType'] ?? '').toString();
            final targetId = (item['targetId'] as num?)?.toInt();
            final allocAmount = (item['amount'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_allocationLabel(targetType, targetId)),
                  Text('₺${allocAmount.toStringAsFixed(2)}'),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── Ödeme Butonu ─────────────────────────────────────────────────────────────

  Widget _buildPayButton(double total) {
    final isCard = _selectedMethod == 'CREDIT_CARD' ||
        _selectedMethod == 'DEBIT_CARD';
    final payableBase =
        _paymentMode == _modeItems ? _selectedItemsTotal() : _sessionContributionAmount();
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: (_paying || payableBase <= 0) ? null : () => _pay(payableBase),
        child: _paying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                isCard ? 'Kartla Öde' : 'Ödeme İste',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ── Ödeme İşlemi ─────────────────────────────────────────────────────────────

  Future<void> _pay(double baseAmount) async {
    setState(() => _paying = true);
    try {
      final isCard = _selectedMethod == 'CREDIT_CARD' ||
          _selectedMethod == 'DEBIT_CARD';
      final allocations = _buildCustomerAllocations(baseAmount);
      await ApiClient.instance.post(
        ApiConstants.customerPaymentsSimulateComplete,
        data: {
          'method': _selectedMethod,
          'amount': double.parse(baseAmount.toStringAsFixed(2)),
          'tipAmount': double.parse(_tipAmount(baseAmount).toStringAsFixed(2)),
          if (allocations.isNotEmpty) 'allocations': allocations,
          'note': 'SIMULATED_CUSTOMER_PAYMENT',
        },
        sessionToken: _sessionToken,
      );
      await ref.read(customerSessionProvider.notifier).refreshOrders();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isCard
                ? 'Odeme tamamlandi (kart - test modu)'
                : 'Odeme tamamlandi (test modu)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(apiErrorMessage(e)),
                backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  // ── Hesabı Böl Dialog ────────────────────────────────────────────────────────

  void _showSplitDialog(BuildContext context, double total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Böl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toplam: ₺${_grandTotal(total).toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Text('Kaç kişiye bölmek istiyorsunuz?'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [2, 3, 4, 5].map((n) {
                final perPerson = _grandTotal(total) / n;
                return ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                      '$n kişi\n₺${perPerson.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat')),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildCustomerAllocations(double baseAmount) {
    if (baseAmount <= 0) return const [];
    if (_paymentMode == _modeSession) {
      final sessionId = (_financialSummary['sessionId'] as num?)?.toInt();
      if (sessionId == null) return const [];
      return [
        {
          'targetType': 'SESSION',
          'targetId': sessionId,
          'amount': double.parse(baseAmount.toStringAsFixed(2)),
        },
      ];
    }

    final grouped = <int, double>{};
    for (final row in _payableUnitRows(_payableItems)) {
      final key = row['key'] as String;
      if (!_selectedUnitKeys.contains(key)) continue;
      final itemId = (row['itemId'] as num?)?.toInt();
      if (itemId == null) continue;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0) continue;
      grouped[itemId] = (grouped[itemId] ?? 0) + amount;
    }

    double remaining = baseAmount;
    final allocations = <Map<String, dynamic>>[];
    for (final entry in grouped.entries) {
      if (remaining <= 0.0001) break;
      final applied = remaining >= entry.value ? entry.value : remaining;
      allocations.add({
        'targetType': 'ORDER_ITEM',
        'targetId': entry.key,
        'amount': double.parse(applied.toStringAsFixed(2)),
      });
      remaining -= applied;
    }
    final sessionId = (_financialSummary['sessionId'] as num?)?.toInt();
    if (remaining > 0.0001 && sessionId != null) {
      allocations.add({
        'targetType': 'SESSION',
        'targetId': sessionId,
        'amount': double.parse(remaining.toStringAsFixed(2)),
      });
    }
    return allocations;
  }

  List<Map<String, dynamic>> _payableUnitRows(List<dynamic> payableItems) {
    final rows = <Map<String, dynamic>>[];
    for (final raw in payableItems) {
      final item = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
      final itemId = (item['orderItemId'] as num?)?.toInt();
      if (itemId == null) continue;
      final name = (item['menuItemName'] ?? '').toString();
      final outstanding = (item['outstandingAmount'] as num?)?.toDouble() ?? 0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      if (outstanding <= 0 || qty <= 0) continue;

      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      final payableUnits = unitPrice > 0
          ? (outstanding / unitPrice).floor().clamp(1, qty)
          : qty;
      final amountPerUnit = unitPrice > 0 ? unitPrice : (outstanding / payableUnits);

      for (var i = 1; i <= payableUnits; i++) {
        final key = '$itemId-$i';
        rows.add({
          'key': key,
          'itemId': itemId,
          'name': name,
          'unitNo': i,
          'amount': amountPerUnit,
        });
      }
    }
    return rows;
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────────

  String _paymentMethodLabel(String method) => switch (method) {
        'CASH' => 'Nakit',
        'CREDIT_CARD' => 'Kredi Kartı',
        'DEBIT_CARD' => 'Banka Kartı',
        'OTHER' => 'Diğer',
        _ => method,
      };

  String _paymentStatusLabel(String status) => switch (status) {
        'COMPLETED' => 'Tamamlandı',
        'PENDING' => 'Bekliyor',
        'FAILED' => 'Başarısız',
        _ => status,
      };

  String _allocationLabel(String targetType, int? targetId) {
    if (targetType == 'ORDER_ITEM') {
      final item = targetId != null ? _orderItemById[targetId] : null;
      final name = (item?['menuItemName'] ?? item?['name'] ?? '').toString().trim();
      final qty = (item?['quantity'] as num?)?.toInt();
      if (name.isNotEmpty) {
        return qty != null && qty > 0 ? '$name x$qty' : name;
      }
      return 'Ürün #${targetId ?? '-'}';
    }
    return switch (targetType) {
      'ORDER' => 'Sipariş #${targetId ?? '-'}',
      'SESSION' => 'Masa Katkısı',
      _ => targetType,
    };
  }

  Map<int, Map<String, dynamic>> _indexOrderItemsById(List<dynamic> orders) {
    final index = <int, Map<String, dynamic>>{};
    for (final order in orders) {
      final map = order is Map ? Map<String, dynamic>.from(order) : const <String, dynamic>{};
      final items = List<dynamic>.from(map['items'] as List? ?? const []);
      for (final rawItem in items) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final id = (item['id'] as num?)?.toInt();
        if (id != null && id > 0) {
          index[id] = item;
        }
      }
    }
    return index;
  }

  String _formatDateTime(String value) {
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _statusLabel(String status) => switch (status) {
        'PENDING' => 'Bekleniyor',
        'PREPARING' => 'Hazırlanıyor',
        'READY' => 'Hazır',
        'DELIVERED' => 'Teslim Edildi',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'PENDING' => Colors.orange,
        'PREPARING' => Colors.blue,
        'READY' => Colors.green,
        'DELIVERED' => Colors.grey,
        _ => Colors.grey,
      };
}
