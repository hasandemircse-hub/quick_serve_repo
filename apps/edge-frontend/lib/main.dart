import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_frontend/core/providers/edge_shell_providers.dart';
import 'package:shared_frontend/shared_frontend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/edge_frontend.env');
    applyFrontendEnvMap(dotenv.env);
  } catch (e, st) {
    debugPrint('edge_frontend.env yüklenemedi; --dart-define değerleri kullanılacak: $e');
    debugPrint('$st');
  }
  await runQuickServeApp(
    providerOverrides: [
      appInitialLocationProvider.overrideWith((ref) => '/login'),
      showEdgeCloudLinkBannerProvider.overrideWith((ref) => true),
    ],
  );
}
