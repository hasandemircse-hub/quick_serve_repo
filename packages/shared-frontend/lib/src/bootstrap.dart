import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_frontend/app.dart';
import 'package:shared_frontend/core/storage/local_storage.dart';

Future<void> runQuickServeApp({List<Override> providerOverrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  runApp(
    ProviderScope(
      overrides: providerOverrides,
      child: const QuickServeApp(),
    ),
  );
}

