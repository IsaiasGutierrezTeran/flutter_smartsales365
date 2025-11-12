// Test básico para SmartSales365

import 'package:flutter_test/flutter_test.dart';

import 'package:smartsales/main.dart';

void main() {
  testWidgets('SmartSalesApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartSalesApp());

    // Verify that splash screen shows up
    expect(find.text('SmartSales365'), findsOneWidget);
    expect(find.text('Sistema de Gestión Inteligente'), findsOneWidget);
  });
}
