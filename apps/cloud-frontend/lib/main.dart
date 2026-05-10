import 'package:flutter/foundation.dart';
import 'package:shared_frontend/shared_frontend.dart';

Future<void> main() async {
  await runQuickServeApp(
    providerOverrides: [
      if (kIsWeb)
        appInitialLocationProvider.overrideWith((ref) => '/login'),
    ],
  );
}
