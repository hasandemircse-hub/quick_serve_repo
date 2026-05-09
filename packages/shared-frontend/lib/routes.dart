import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/customer/screens/menu_screen.dart';
import 'features/customer/screens/cart_screen.dart';
import 'features/customer/screens/payment_screen.dart';
import 'features/customer/screens/review_screen.dart';
import 'features/waiter/screens/waiter_home_screen.dart';
import 'features/waiter/screens/waiter_session_order_screen.dart';
import 'features/kitchen/screens/kitchen_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/superadmin/screens/superadmin_screen.dart';
import 'features/customer/screens/qr_scan_screen.dart';
import 'features/cashier/screens/cashier_screen.dart';

/// Cloud müşteri uygulaması `/scan`; edge personel uygulaması bootstrap’ta `/login` ile override edilir.
final appInitialLocationProvider = Provider<String>((ref) => '/scan');

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    initialLocation: ref.watch(appInitialLocationProvider),
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = authNotifier.state.isAuthenticated;
      final userRole = authNotifier.state.role;
      final location = state.uri.path;

      // Protected routes that require authentication
      final protectedRoutes = ['/admin', '/superadmin', '/waiter', '/kitchen', '/cashier'];

      // Check if current route is protected
      final isProtectedRoute = protectedRoutes.any((route) => location.startsWith(route));

      if (isProtectedRoute && !isAuthenticated) {
        // Redirect to login if not authenticated
        return '/login';
      }

      // Check role-based access
      if (location.startsWith('/admin') && !authNotifier.hasRole('RESTAURANT_ADMIN')) {
        return '/login';
      }

      if (location.startsWith('/superadmin') && !authNotifier.hasRole('SUPERADMIN')) {
        return '/login';
      }

      if (location.startsWith('/waiter') && !authNotifier.hasRole('WAITER')) {
        return '/login';
      }

      if (location.startsWith('/cashier') && !authNotifier.hasRole('WAITER')) {
        return '/login';
      }

      if (location.startsWith('/kitchen') && !authNotifier.hasRole('CHEF')) {
        return '/login';
      }

      // If user is authenticated and trying to access login, redirect to appropriate dashboard
      if (isAuthenticated && location == '/login') {
        switch (userRole) {
          case 'SUPERADMIN':
            return '/superadmin';
          case 'RESTAURANT_ADMIN':
            return '/admin';
          case 'WAITER':
          case 'HEAD_WAITER':
            return '/waiter';
          case 'CHEF':
            return '/kitchen';
          case 'VALET':
            return '/waiter'; // TODO: Create valet screen
          default:
            return '/scan';
        }
      }

      return null; // No redirect needed
    },
    routes: [
      // ─── Müşteri Rotaları ───────────────────────────────────────────────
      GoRoute(
        path: '/scan',
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/scan/:qrToken',
        builder: (context, state) {
          final token = state.pathParameters['qrToken']!;
          return MenuScreen(qrToken: token);
        },
      ),
      GoRoute(
        path: '/menu',
        builder: (context, state) => const MenuScreen(),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) => const PaymentScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) => const ReviewScreen(),
      ),

      // ─── Personel Girişi ─────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ─── Garson ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/waiter',
        builder: (context, state) => const WaiterHomeScreen(),
      ),
      GoRoute(
        path: '/waiter/session-order',
        builder: (context, state) {
          final sessionIdStr = state.uri.queryParameters['sessionId'] ?? '';
          final tableNumber = state.uri.queryParameters['tableNumber'] ?? '?';
          final sessionId = int.tryParse(sessionIdStr) ?? 0;
          if (sessionId <= 0) {
            return const Scaffold(
              body: Center(child: Text('Geçersiz oturum')),
            );
          }
          return WaiterSessionOrderScreen(
            sessionId: sessionId,
            tableNumber: tableNumber,
          );
        },
      ),
      GoRoute(
        path: '/cashier',
        builder: (context, state) {
          final sid = state.uri.queryParameters['sessionId'];
          final initialSessionId = sid != null ? int.tryParse(sid) : null;
          return CashierScreen(initialSessionId: initialSessionId);
        },
      ),

      // ─── Mutfak ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/kitchen',
        builder: (context, state) => const KitchenScreen(),
      ),

      // ─── Restoran Admin ──────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // ─── Superadmin ──────────────────────────────────────────────────────
      GoRoute(
        path: '/superadmin',
        builder: (context, state) => const SuperadminScreen(),
      ),
    ],
  );
});
