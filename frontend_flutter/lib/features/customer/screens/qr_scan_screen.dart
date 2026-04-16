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
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: [BarcodeFormat.qrCode],
    torchEnabled: false,
  );

  bool _scanned = false;
  bool _torchOn = false;
  double _zoomFactor = 0.0;

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
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 2 &&
        pathSegments[pathSegments.length - 2] == 'scan') {
      final qrToken = pathSegments.last;
      setState(() => _scanned = true);
      _controller.stop();
      context.go('/scan/$qrToken');
    } else if (pathSegments.contains('staff') &&
        pathSegments.contains('login')) {
      setState(() => _scanned = true);
      _controller.stop();
      context.go('/login');
    }
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  void _onZoomChanged(double value) {
    setState(() => _zoomFactor = value);
    _controller.setZoomScale(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QR Kodu Okutun'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'El feneri',
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Kamera
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Karartma + çerçeve
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScanOverlayPainter(),
          ),

          // Alt bilgi + zoom
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(
              children: [
                const Text(
                  'QR kodu çerçeveye hizalayın',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _zoomFactor,
                          min: 0.0,
                          max: 1.0,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white30,
                          onChanged: _onZoomChanged,
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ekranı karartıp ortaya şeffaf kare açan painter.
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cutoutSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40;

    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy),
            width: cutoutSize,
            height: cutoutSize),
        const Radius.circular(12),
      ));

    final overlay = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(overlay,
        Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Köşe işaretleri
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cornerLen = 28.0;
    final l = cx - cutoutSize / 2;
    final t = cy - cutoutSize / 2;
    final r = cx + cutoutSize / 2;
    final b = cy + cutoutSize / 2;

    // Sol üst
    canvas.drawLine(Offset(l, t + cornerLen), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + cornerLen, t), cornerPaint);
    // Sağ üst
    canvas.drawLine(Offset(r - cornerLen, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cornerLen), cornerPaint);
    // Sol alt
    canvas.drawLine(Offset(l, b - cornerLen), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + cornerLen, b), cornerPaint);
    // Sağ alt
    canvas.drawLine(Offset(r - cornerLen, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
