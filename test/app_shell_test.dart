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

  testWidgets('shows invoice form and navigates to the receipt form', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(ShippingSystemApp(database: database));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('بيانات الفاتورة'), findsOneWidget);

    await tester.tap(find.text('سند قبض - شيك'));
    await tester.pump();
    expect(find.text('بيانات سند القبض'), findsOneWidget);
  });
}
