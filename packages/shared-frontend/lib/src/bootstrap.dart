import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_frontend/app.dart';
import 'package:shared_frontend/core/storage/local_storage.dart';

Future<void> runQuickServeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  runApp(
    const ProviderScope(
      child: QuickServeApp(),
    ),
  );
}

