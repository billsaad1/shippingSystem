import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_system/data/local_database.dart';
import 'package:shipping_system/models/document_models.dart';
import 'package:shipping_system/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a landscape shipping invoice PDF', () async {
    final bytes = await PdfService.invoice(
      const ShippingInvoice(
        invoiceNumber: 'TEST-1',
        invoiceDate: '03/11/2026',
        customerName: 'عميل تجريبي',
        billOfLadingNumber: 'BL-001',
        currency: 'USD',
        chargeLines: [
          ChargeLine(
            payee: 'أجور شحن',
            description: 'رسوم الشحن',
            amount: '120.00',
          ),
        ],
      ),
      company: const CompanyProfile(
        arabicName: 'شركة شحن تجريبية',
        englishName: 'Test Shipping Co.',
        logoPath: 'assets/images/company_mark.png',
      ),
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
    await File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}shipping-system-invoice-test.pdf',
    ).writeAsBytes(bytes);
  });

  test('generates a landscape receipt PDF', () async {
    final bytes = await PdfService.receipt(
      const ReceiptVoucher(
        receiptNumber: 'TEST-2',
        receiptDate: '03/11/2026',
        customerName: 'عميل تجريبي',
        amount: '120.00',
        bankName: 'البنك التجريبي',
        chequeNumber: 'CHK-10',
        description: 'رسوم تحضير حاوية',
        sourceInvoiceNumber: 'TEST-1',
      ),
      company: const CompanyProfile(
        arabicName: 'شركة شحن تجريبية',
        englishName: 'Test Shipping Co.',
        logoPath: 'assets/images/company_mark.png',
        signature1Label: 'المستلم',
        signature2Label: 'المحاسب',
        signature3Label: '',
      ),
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
    await File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}shipping-system-receipt-test.pdf',
    ).writeAsBytes(bytes);
  });

  test('stores and retrieves invoices and receipts in SQLite', () async {
    final database = await LocalDatabase.openInMemory();
    try {
      const invoice = ShippingInvoice(
        invoiceNumber: 'DB-1',
        invoiceDate: '03/11/2026',
        customerName: 'عميل قاعدة البيانات',
      );
      const receipt = ReceiptVoucher(
        receiptNumber: 'DB-2',
        receiptDate: '03/11/2026',
        customerName: 'مستلم تجريبي',
        amount: '55.50',
        sourceInvoiceNumber: 'DB-1',
      );
      const profile = CompanyProfile(
        arabicName: 'شركة قاعدة البيانات',
        englishName: 'Database Shipping Co.',
      );

      await database.saveInvoice(invoice);
      await database.saveReceipt(receipt);
      await database.saveCompanyProfile(profile);

      expect((await database.recentInvoices()).single.invoiceNumber, 'DB-1');
      expect((await database.recentReceipts()).single.numericAmount, 55.5);
      expect(
        (await database.recentReceipts()).single.sourceInvoiceNumber,
        'DB-1',
      );
      expect(
        (await database.getCompanyProfile()).arabicName,
        'شركة قاعدة البيانات',
      );
    } finally {
      await database.close();
    }
  });
}
