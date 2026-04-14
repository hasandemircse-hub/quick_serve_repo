import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _selectedMethod = 'CASH';
  double _tip = 0;
  final double _total = 0;
  bool _loading = false;

  final List<Map<String, dynamic>> _methods = [
    {'key': 'CREDIT_CARD', 'label': 'Kredi Kartı', 'icon': Icons.credit_card},
    {'key': 'DEBIT_CARD', 'label': 'Banka Kartı', 'icon': Icons.credit_card_outlined},
    {'key': 'CASH', 'label': 'Nakit', 'icon': Icons.money},
    {'key': 'OTHER', 'label': 'Diğer', 'icon': Icons.more_horiz},
  ];

  final List<double> _tipOptions = [0, 5, 10, 15, 20];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ödeme')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tutar özeti
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Yemek Tutarı'),
                        Text('${_total.toStringAsFixed(2)} ₺',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bahşiş'),
                        Text('${_tip.toStringAsFixed(2)} ₺',
                            style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Toplam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${(_total + _tip).toStringAsFixed(2)} ₺',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                                color: Color(0xFFE53935))),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bahşiş
            const Text('Bahşiş', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _tipOptions.map((t) => ChoiceChip(
                label: Text(t == 0 ? 'Yok' : '%${t.toInt()}'),
                selected: _tip == (_total * t / 100),
                onSelected: (_) => setState(() { _tip = _total * t / 100; }),
              )).toList(),
            ),

            const SizedBox(height: 24),

            // Ödeme yöntemi
            const Text('Ödeme Yöntemi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selectedMethod,
              onChanged: (v) => setState(() { _selectedMethod = v!; }),
              child: Column(
                children: _methods.map((m) => RadioListTile<String>(
                  value: m['key'],
                  title: Text(m['label']),
                  secondary: Icon(m['icon']),
                )).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Hesap bölme butonu
            OutlinedButton.icon(
              onPressed: () => _showSplitDialog(context),
              icon: const Icon(Icons.people),
              label: const Text('Hesabı Böl'),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _loading ? null : _pay,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_selectedMethod == 'CREDIT_CARD' || _selectedMethod == 'DEBIT_CARD'
                        ? 'Kartla Öde' : 'Ödeme İste'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay() async {
    setState(() { _loading = true; });
    final sessionToken = await LocalStorage.getSessionToken();
    if (sessionToken == null) return;

    try {
      if (_selectedMethod == 'CREDIT_CARD' || _selectedMethod == 'DEBIT_CARD') {
        // İyzico ödeme sayfası başlat
        await ApiClient.instance.post(ApiConstants.customerPaymentsInit,
            data: {
              'method': _selectedMethod,
              'amount': _total,
              'tipAmount': _tip,
            },
            sessionToken: sessionToken);
        // TODO: res.data['paymentUrl'] → url_launcher ile aç
      } else {
        // Nakit: garson onayı bekle
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Garsonunuz kısa süre içinde size gelecek')));
          context.go('/review');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _showSplitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Böl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kaç kişiye bölmek istiyorsunuz?'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [2, 3, 4, 5].map((n) => ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // TODO: Bölme API çağrısı
                },
                child: Text('$n Kişi'),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
