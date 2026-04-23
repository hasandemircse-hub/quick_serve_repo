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
  String _selectedMethod = 'CASH';
  double _tip = 0;
  bool _loadingOrders = true;
  bool _paying = false;
  String? _sessionToken;

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

  Future<void> _loadData() async {
    _sessionToken = await LocalStorage.getSessionToken();
    if (_sessionToken == null) {
      if (mounted) context.go('/scan');
      return;
    }
    try {
      final res = await ApiClient.instance
          .get(ApiConstants.customerOrders, sessionToken: _sessionToken);
      final orders = List<dynamic>.from(res.data);
      await ref.read(customerSessionProvider.notifier).setSession(_sessionToken!);
      setState(() {
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
    return orders
        .where((o) => o['status'] != 'CANCELLED')
        .fold<double>(
            0, (s, o) => s + ((o['totalAmount'] as num?)?.toDouble() ?? 0));
  }

  double _tipAmount(double total) => total * _tip / 100;
  double _grandTotal(double total) => total + _tipAmount(total);

  @override
  Widget build(BuildContext context) {
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
                  _buildOrderList(orders),
                  const SizedBox(height: 16),
                  _buildTipSection(),
                  const SizedBox(height: 16),
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 16),
                  _buildSplitButton(total),
                  const SizedBox(height: 24),
                  _buildPayButton(total),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ── Tutar Özeti ─────────────────────────────────────────────────────────────

  Widget _buildSummaryCard(double total) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Yemek Tutarı',
                '₺${total.toStringAsFixed(2)}', null),
            if (_tip > 0) ...[
              const SizedBox(height: 6),
              _summaryRow('Bahşiş (%${_tip.toInt()})',
                  '₺${_tipAmount(total).toStringAsFixed(2)}', Colors.green),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            _summaryRow(
              'Toplam',
              '₺${_grandTotal(total).toStringAsFixed(2)}',
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

  // ── Ödeme Butonu ─────────────────────────────────────────────────────────────

  Widget _buildPayButton(double total) {
    final isCard = _selectedMethod == 'CREDIT_CARD' ||
        _selectedMethod == 'DEBIT_CARD';
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: (_paying || total == 0) ? null : () => _pay(total),
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

  Future<void> _pay(double total) async {
    setState(() => _paying = true);
    try {
      final isCard = _selectedMethod == 'CREDIT_CARD' ||
          _selectedMethod == 'DEBIT_CARD';
      if (isCard) {
        await ApiClient.instance.post(
          ApiConstants.customerPaymentsInit,
          data: {
            'method': _selectedMethod,
            'amount': _grandTotal(total),
            'tipAmount': _tipAmount(total),
          },
          sessionToken: _sessionToken,
        );
        // TODO: res.data['paymentUrl'] → url_launcher ile aç
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Garsonunuz kısa süre içinde size gelecek')));
          context.go('/review');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Hata: $e'),
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

  // ── Yardımcılar ──────────────────────────────────────────────────────────────

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
