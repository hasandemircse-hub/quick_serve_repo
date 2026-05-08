import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_session_events.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/customer_session_provider.dart';
import 'routes.dart';

class QuickServeApp extends ConsumerStatefulWidget {
  const QuickServeApp({super.key});

  @override
  ConsumerState<QuickServeApp> createState() => _QuickServeAppState();
}

class _QuickServeAppState extends ConsumerState<QuickServeApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  VoidCallback? _unauthorizedListener;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(customerSessionProvider.notifier).init();
    });

    _unauthorizedListener = () async {
      // 401 sonrası tek noktadan oturum kapat + login ekranına dön.
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      ref.read(routerProvider).go('/login');
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Oturum süresi doldu, lütfen tekrar giriş yapın.'),
        ),
      );
    };
    AuthSessionEvents.unauthorizedSignal.addListener(_unauthorizedListener!);
  }

  @override
  void dispose() {
    final listener = _unauthorizedListener;
    if (listener != null) {
      AuthSessionEvents.unauthorizedSignal.removeListener(listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final customerState = ref.watch(customerSessionProvider);
    final toast = customerState.lastToastEvent;
    if (toast != null) {
      Future.microtask(() {
        final isDelivered = toast.status == 'DELIVERED';
        HapticFeedback.mediumImpact();
        if (isDelivered) {
          HapticFeedback.heavyImpact();
        }

        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isDelivered ? Icons.done_all_rounded : Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(toast.message)),
              ],
            ),
            backgroundColor: isDelivered ? Colors.green : Colors.orange,
          ),
        );
        ref.read(customerSessionProvider.notifier).consumeToast();
      });
    }

    return MaterialApp.router(
      title: 'QuickServe',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
    );
  }
}
