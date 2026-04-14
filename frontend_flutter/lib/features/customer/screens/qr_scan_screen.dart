import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Müşteri QR okutma ekranı.
/// Kamerayı açar, QR kodu okur ve menü ekranına yönlendirir.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final url = barcode.rawValue ?? '';
    // URL: http://host/scan/{qrToken} veya http://host/staff/login
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 2 && pathSegments[pathSegments.length - 2] == 'scan') {
      // Müşteri QR: /scan/{qrToken}
      final qrToken = pathSegments.last;
      setState(() { _scanned = true; });
      _controller.stop();
      context.go('/scan/$qrToken');
    } else if (pathSegments.contains('staff') && pathSegments.contains('login')) {
      // Personel QR: /staff/login
      setState(() { _scanned = true; });
      _controller.stop();
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kodu Okutun'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Kılavuz çerçevesi
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0, right: 0,
            child: Text(
              'Masanızdaki QR kodu çerçeveye hizalayın',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  shadows: [const Shadow(blurRadius: 4, color: Colors.black)]),
            ),
          ),
        ],
      ),
    );
  }
}
