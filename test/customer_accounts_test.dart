import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_system/data/local_database.dart';
import 'package:shipping_system/models/document_models.dart';
import 'package:shipping_system/services/money_minor_units.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoneyMinorUnits', () {
    test('parses grouped and Arabic decimal amounts exactly', () {
      expect(MoneyMinorUnits.parse('12,345.67'), 1234567);
      expect(MoneyMinorUnits.parse('١٢٣٤٫٥٠'), 123450);
      expect(MoneyMinorUnits.parse('۱۲۳٫۴۵'), 12345);
      expect(MoneyMinorUnits.format(-1234567), '-12,345.67');
      expect(MoneyMinorUnits.tryParse('12.345'), isNull);
    });
  });

  test(
    'posts invoices and receipts once and allocates partial payments',
    () async {
      final database = await LocalDatabase.openInMemory();
      try {
        final customerId = await database.saveInvoice(
          const ShippingInvoice(
            invoiceNumber: 'AR-100',
            invoiceDate: '04/11/2026',
            currency: 'USD',
            customerName: 'شركة الاختبار',
            customerNumber: 'C-100',
            chargeLines: [
              ChargeLine(
                payee: 'الشحن',
                description: 'رسوم شحن',
                amount: '70.25',
              ),
              ChargeLine(
                payee: 'الميناء',
                description: 'مناولة',
                amount: '35.50',
              ),
            ],
            discount: '5.75',
          ),
        );
        expect(customerId, isNotNull);

        await database.saveReceipt(
          ReceiptVoucher(
            receiptNumber: 'RC-1',
            receiptDate: '05/11/2026',
            customerName: 'شركة الاختبار',
            customerId: customerId,
            amount: '20.25',
            currency: 'USD',
            sourceInvoiceNumber: 'AR-100',
            description: 'دفعة جزئية',
          ),
        );

        expect(await database.invoiceOutstandingMinor('AR-100'), 7975);
        expect((await database.customerBalances(customerId!))['USD'], 7975);
        expect((await database.customerStatement(customerId)).length, 2);

        await database.saveReceipt(
          ReceiptVoucher(
            receiptNumber: 'RC-1',
            receiptDate: '05/11/2026',
            customerName: 'شركة الاختبار',
            customerId: customerId,
            amount: '30.25',
            currency: 'USD',
            sourceInvoiceNumber: 'AR-100',
            description: 'تعديل الدفعة',
          ),
        );
        expect(await database.invoiceOutstandingMinor('AR-100'), 6975);
        expect((await database.customerBalances(customerId))['USD'], 6975);
        expect((await database.customerStatement(customerId)).length, 2);

        final accounts = await database.customerAccounts();
        expect(accounts, hasLength(1));
        expect(accounts.single.customer.customerNumber, 'C-100');
        expect(accounts.single.usdBalanceMinor, 6975);
        expect(accounts.single.yerBalanceMinor, 0);
      } finally {
        await database.close();
      }
    },
  );

  test('keeps USD and YER account balances separate', () async {
    final database = await LocalDatabase.openInMemory();
    try {
      final customerId = await database.saveInvoice(
        const ShippingInvoice(
          invoiceNumber: 'MIXED-1',
          invoiceDate: '04/11/2026',
          currency: 'USD',
          customerName: 'عميل بعملتين',
          customerNumber: 'C-2',
          chargeLines: [ChargeLine(amount: '12.34')],
        ),
      );
      await database.saveInvoice(
        ShippingInvoice(
          invoiceNumber: 'MIXED-2',
          invoiceDate: '04/11/2026',
          currency: 'YER',
          customerName: 'عميل بعملتين',
          customerNumber: 'C-2',
          customerId: customerId,
          chargeLines: const [ChargeLine(amount: '200.00')],
        ),
      );
      await database.saveReceipt(
        ReceiptVoucher(
          receiptNumber: 'MIXED-R',
          receiptDate: '05/11/2026',
          customerName: 'عميل بعملتين',
          customerId: customerId,
          amount: '50.00',
          currency: 'YER',
        ),
      );
      final balances = await database.customerBalances(customerId!);
      expect(balances['USD'], 1234);
      expect(balances['YER'], 15000);
    } finally {
      await database.close();
    }
  });

  test('migrates existing invoices and receipts into customer ledgers', () async {
    sqfliteFfiInit();
    final path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'shipping-system-migration-${DateTime.now().microsecondsSinceEpoch}.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE invoices (
              invoice_number TEXT PRIMARY KEY,
              invoice_date TEXT NOT NULL,
              customer_name TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE receipts (
              receipt_number TEXT PRIMARY KEY,
              receipt_date TEXT NOT NULL,
              customer_name TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE company_profile (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              payload_json TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    final oldInvoice = const ShippingInvoice(
      invoiceNumber: 'OLD-I-1',
      invoiceDate: '03/11/2026',
      currency: 'USD',
      customerName: 'عميل قديم',
      customerNumber: 'OLD-7',
      chargeLines: [ChargeLine(amount: '250.00')],
    );
    final oldReceipt = const ReceiptVoucher(
      receiptNumber: 'OLD-R-1',
      receiptDate: '04/11/2026',
      customerName: 'عميل قديم',
      amount: '75.00',
      currency: 'USD',
      sourceInvoiceNumber: 'OLD-I-1',
    );
    final now = DateTime.now().toIso8601String();
    await legacy.insert('invoices', {
      'invoice_number': oldInvoice.invoiceNumber,
      'invoice_date': oldInvoice.invoiceDate,
      'customer_name': oldInvoice.customerName,
      'payload_json': jsonEncode(oldInvoice.toJson()),
      'updated_at': now,
    });
    await legacy.insert('receipts', {
      'receipt_number': oldReceipt.receiptNumber,
      'receipt_date': oldReceipt.receiptDate,
      'customer_name': oldReceipt.customerName,
      'payload_json': jsonEncode(oldReceipt.toJson()),
      'updated_at': now,
    });
    await legacy.close();

    final upgraded = await LocalDatabase.openAtPathForTesting(path);
    try {
      final accounts = await upgraded.customerAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.single.customer.customerNumber, 'OLD-7');
      expect(accounts.single.usdBalanceMinor, 17500);
      expect(await upgraded.invoiceOutstandingMinor('OLD-I-1'), 17500);
      final statement = await upgraded.customerStatement(
        accounts.single.customer.id!,
      );
      expect(statement, hasLength(2));
      expect(statement.every((entry) => entry.isLegacy), isTrue);
    } finally {
      await upgraded.close();
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  });
}
