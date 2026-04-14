import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';
import 'menu_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold(0.0, (sum, i) => sum + i.price * i.quantity);

    return Scaffold(
      appBar: AppBar(title: const Text('Sepetim')),
      body: cart.isEmpty
          ? const Center(child: Text('Sepetiniz boş'))
          : ListView.builder(
              itemCount: cart.length,
              itemBuilder: (ctx, i) {
                final item = cart[i];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.price.toStringAsFixed(2)} ₺'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('x${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('${(item.price * item.quantity).toStringAsFixed(2)} ₺'),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Toplam:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${total.toStringAsFixed(2)} ₺',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFFE53935))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => _placeOrder(context, ref),
                  child: const Text('Sipariş Ver', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final sessionToken = await LocalStorage.getSessionToken();
    if (sessionToken == null) return;

    try {
      final items = cart.map((i) => {
        'menuItemId': int.parse(i.id),
        'quantity': i.quantity,
        'note': i.note,
      }).toList();

      await ApiClient.instance.post(ApiConstants.customerOrders,
          data: {'items': items}, sessionToken: sessionToken);

      ref.read(cartProvider.notifier).clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Siparişiniz alındı!')));
        context.go('/menu');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sipariş gönderilemedi: $e')));
      }
    }
  }
}
