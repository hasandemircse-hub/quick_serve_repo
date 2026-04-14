import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter/app.dart';

void main() {
  testWidgets('QuickServe app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: QuickServeApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
