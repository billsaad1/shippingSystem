import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_system/data/local_database.dart';
import 'package:shipping_system/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDatabase database;

  setUpAll(() async {
    database = await LocalDatabase.openInMemory();
  });

  tearDownAll(() async {
    await database.close();
  });

  testWidgets('adds a customer and opens its account statement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(ShippingSystemApp(database: database));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('العملاء والحسابات').first);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('لا توجد بطاقات عملاء بعد'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-customer-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customer-field-name')),
      'عميل الواجهة',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-field-customerNumber')),
      'UI-100',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('عميل الواجهة'), findsOneWidget);
    expect(find.text('رقم UI-100'), findsOneWidget);

    await tester.tap(find.text('عميل الواجهة'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('كشف حساب عميل الواجهة'), findsOneWidget);
    expect(find.text('لا توجد حركات حساب لهذا العميل بعد.'), findsOneWidget);
  });
}
