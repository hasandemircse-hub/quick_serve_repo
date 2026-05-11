import 'api_runtime_config.dart';

class ApiConstants {
  /// Çoğunlukla edge tabanı; runtime `edge_frontend.env` ile güncellenebilir.
  static String get baseUrl => ApiRuntimeConfig.effectiveBaseUrl;

  static String get cloudBaseUrl => ApiRuntimeConfig.effectiveCloudBaseUrl;

  static String get edgeBaseUrl => ApiRuntimeConfig.effectiveEdgeBaseUrl;

  // Web admin URL (personel için gizli, sadece bilenler erişir)
  static String get webAdminUrl => ApiRuntimeConfig.effectiveWebAdminUrl;

  // Auth
  static const String login = '/auth/login';

  // Customer
  static const String scanQr = '/customer/scan';
  static const String customerSession = '/customer/session';
  static const String customerMenu = '/customer/menu';
  static const String customerOrders = '/customer/orders';
  static const String customerPayments = '/customer/payments';
  static const String customerPaymentsInit = '/customer/payments/iyzico/init';
  static const String customerPaymentsSimulateComplete =
      '/customer/payments/simulate-complete';
  static const String customerPaymentsFinancialSummary =
      '/customer/payments/financial-summary';
  static const String customerPaymentsPayableItems =
      '/customer/payments/payable-items';
  static const String customerPaymentsSplit = '/customer/payments/split';
  static const String customerCallWaiter = '/customer/calls/waiter';
  static const String customerCallBill = '/customer/calls/bill';
  static const String customerReviews = '/customer/reviews';

  // Waiter
  static const String waiterTables = '/waiter/tables';
  static const String waiterMenu = '/waiter/menu';
  static const String waiterCalls = '/waiter/calls';
  static const String waiterOrders = '/waiter/orders';
  static const String waiterPaymentsCash = '/waiter/payments/cash';
  static const String waiterSessionOrders = '/waiter/sessions';
  static const String waiterSessionPosInit =
      '/waiter/sessions/{sessionId}/payments/pos/init';
  static const String waiterSessionPosConfirm =
      '/waiter/sessions/{sessionId}/payments/pos/{posIntentId}/confirm';
  static const String waiterSessionPosCancel =
      '/waiter/sessions/{sessionId}/payments/pos/{posIntentId}/cancel';
  static const String waiterSessionPosStatus =
      '/waiter/sessions/{sessionId}/payments/pos/{posIntentId}/status';

  // Kitchen
  static const String kitchenOrders = '/kitchen/orders';

  // Admin
  static const String adminTables = '/admin/tables';
  static const String adminTableLayout = '/admin/tables/layout';
  static const String adminTableGroups = '/admin/table-groups';
  static const String adminTableGroupsReorder = '/admin/table-groups/reorder';
  static const String adminMenuCategories = '/admin/menu/categories';
  static const String adminMenuCategoriesReorder =
      '/admin/menu/categories/reorder';
  static const String adminMenuItems = '/admin/menu/items';
  static const String adminMenuItemsReorder = '/admin/menu/items/reorder';
  static const String adminStaff = '/admin/staff';
  static const String adminReviews = '/admin/reviews';

  // Superadmin
  static const String superadminRestaurants = '/superadmin/restaurants';
  static const String superadminEdgeNodes = '/superadmin/edge-nodes';
  static const String superadminFeatureFlags = '/superadmin/feature-flags';
  static const String superadminAuditLogs = '/superadmin/audit-logs';

  // Notifications
  static const String notifications = '/notifications';
  static const String unreadNotifications = '/notifications/unread';

  // WebSocket
  static const String wsEndpoint = '/ws';
}
