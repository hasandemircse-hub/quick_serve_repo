class ApiConstants {
  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080/api');

  // Web admin URL (personel için gizli, sadece bilenler erişir)
  static const String webAdminUrl =
      String.fromEnvironment('WEB_ADMIN_URL', defaultValue: 'http://localhost:8080/auth/admin');

  // Auth
  static const String login = '/auth/login';

  // Customer
  static const String scanQr = '/customer/scan';
  static const String customerSession = '/customer/session';
  static const String customerMenu = '/customer/menu';
  static const String customerOrders = '/customer/orders';
  static const String customerPaymentsInit = '/customer/payments/iyzico/init';
  static const String customerPaymentsSplit = '/customer/payments/split';
  static const String customerCallWaiter = '/customer/calls/waiter';
  static const String customerCallBill = '/customer/calls/bill';
  static const String customerReviews = '/customer/reviews';

  // Waiter
  static const String waiterTables = '/waiter/tables';
  static const String waiterCalls = '/waiter/calls';
  static const String waiterOrders = '/waiter/orders';
  static const String waiterPaymentsCash = '/waiter/payments/cash';

  // Kitchen
  static const String kitchenOrders = '/kitchen/orders';

  // Admin
  static const String adminTables = '/admin/tables';
  static const String adminTableLayout = '/admin/tables/layout';
  static const String adminMenuCategories = '/admin/menu/categories';
  static const String adminMenuCategoriesReorder = '/admin/menu/categories/reorder';
  static const String adminMenuItems = '/admin/menu/items';
  static const String adminMenuItemsReorder = '/admin/menu/items/reorder';
  static const String adminStaff = '/admin/staff';
  static const String adminReviews = '/admin/reviews';

  // Superadmin
  static const String superadminRestaurants = '/superadmin/restaurants';

  // Notifications
  static const String notifications = '/notifications';
  static const String unreadNotifications = '/notifications/unread';

  // WebSocket
  static const String wsEndpoint = '/ws';
}
