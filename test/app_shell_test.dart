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

  testWidgets('creates a receipt from an invoice and opens company settings', (
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
    expect(find.text('بيانات الفاتورة'), findsOneWidget);

    Future<void> enterField(String key, String value) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, value);
    }

    TextFormField field(String key) =>
        tester.widget<TextFormField>(find.byKey(ValueKey(key)));

    await enterField('invoice-field-رقم الفاتورة', 'LINK-TEST-1');
    await enterField('invoice-field-اسم العميل', 'عميل الربط');
    await enterField('invoice-field-اسم المستحق', 'أجور الشحن');
    await enterField('invoice-field-المبلغ', '123.50');
    expect(field('invoice-field-رقم الفاتورة').controller?.text, 'LINK-TEST-1');
    expect(field('invoice-field-اسم العميل').controller?.text, 'عميل الربط');
    expect(field('invoice-field-اسم المستحق').controller?.text, 'أجور الشحن');
    expect(field('invoice-field-المبلغ').controller?.text, '123.50');
    final createReceipt = find.widgetWithText(
      OutlinedButton,
      'إنشاء سند من الفاتورة',
    );
    await tester.ensureVisible(createReceipt);
    await tester.tap(createReceipt);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('هذا الحقل مطلوب'), findsNothing);
    expect(
      tester
          .widgetList<IndexedStack>(find.byType(IndexedStack))
          .any((stack) => stack.index == 1),
      isTrue,
    );

    expect(find.text('بيانات سند القبض'), findsOneWidget);
    expect(
      field('receipt-field-استلمنا من (اسم العميل)').controller?.text,
      'عميل الربط',
    );
    expect(field('receipt-field-المبلغ بالأرقام').controller?.text, '123.50');
    expect(
      field('receipt-field-البيان').controller?.text,
      contains('LINK-TEST-1'),
    );
    expect(
      field('receipt-readonly-الفاتورة المرتبطة-LINK-TEST-1').initialValue,
      'LINK-TEST-1',
    );

    await tester.tap(find.text('بيانات الشركة'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('إعدادات الشركة'), findsOneWidget);
    expect(find.text('الترويسة العربية'), findsOneWidget);

    await tester.tap(find.text('العملاء والحسابات').first);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('عميل الربط'), findsOneWidget);

    await tester.tap(find.text('عميل الربط'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('كشف حساب عميل الربط'), findsOneWidget);
    expect(find.text('123.50'), findsAtLeastNWidgets(1));
  });
}
