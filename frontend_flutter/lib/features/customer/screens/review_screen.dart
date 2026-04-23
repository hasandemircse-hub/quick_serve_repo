import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/customer_session_provider.dart';
import '../../../core/storage/local_storage.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _formKey = GlobalKey<FormState>();
  final _commentCtrl = TextEditingController();
  bool _submitted = false;
  bool _ratingError = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _ratingError = _rating == 0; });
    if (_rating == 0) return;
    if (!_formKey.currentState!.validate()) return;

    final sessionToken = await LocalStorage.getSessionToken();
    if (sessionToken == null) return;

    try {
      await ApiClient.instance.post(ApiConstants.customerReviews,
          data: {'rating': _rating, 'comment': _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim()},
          sessionToken: sessionToken);
      await LocalStorage.clearSessionToken();
      if (!mounted) return;
      ProviderScope.containerOf(context, listen: false)
          .read(customerSessionProvider.notifier)
          .clearSession();
      setState(() { _submitted = true; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text('Değerlendirmeniz alındı, teşekkürler!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/scan'),
                child: const Text('Ana Sayfaya Dön'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Değerlendirme')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Deneyiminizi puanlayın',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                iconSize: 40,
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() {
                  _rating = i + 1;
                  _ratingError = false;
                }),
              )),
            ),
            if (_ratingError)
              const Text('Lütfen bir puan seçin',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yorum (opsiyonel)',
                  border: OutlineInputBorder(),
                  hintText: 'Deneyiminizi paylaşın...',
                ),
                maxLines: 4,
                maxLength: 500,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.trim().length < 3) {
                    return 'Yorum en az 3 karakter olmalıdır';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Gönder'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/scan'),
              child: const Text('Atla'),
            ),
          ],
        ),
      ),
    );
  }
}
