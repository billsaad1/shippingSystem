import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipping_system/models/document_models.dart';
import 'package:shipping_system/services/amount_to_words.dart';

void main() {
  group('ShippingInvoice', () {
    test('calculates subtotal and total after discount', () {
      const invoice = ShippingInvoice(
        chargeLines: [
          ChargeLine(payee: 'أجور شحن', description: 'حاوية', amount: '120.00'),
          ChargeLine(payee: 'رسوم', description: 'مناولة', amount: '30'),
        ],
        discount: '5.00',
      );

      expect(invoice.subtotal, 150);
      expect(invoice.total, 145);
    });

    test('round-trips invoice and charge lines through JSON', () {
      const invoice = ShippingInvoice(
        invoiceNumber: '878',
        invoiceDate: '03/11/2026',
        customerName: 'عميل تجريبي',
        chargeLines: [
          ChargeLine(
            payee: 'أجور شحن',
            description: 'حاوية',
            amount: '34484.00',
          ),
        ],
      );

      final decoded =
          jsonDecode(jsonEncode(invoice.toJson())) as Map<String, dynamic>;
      final restored = ShippingInvoice.fromJson(decoded);

      expect(restored.invoiceNumber, invoice.invoiceNumber);
      expect(restored.customerName, invoice.customerName);
      expect(restored.chargeLines.single.payee, 'أجور شحن');
      expect(restored.total, 34484);
    });
  });

  group('CompanyProfile and linked receipt', () {
    test('round-trips company identity, logo and signature labels', () {
      const profile = CompanyProfile(
        arabicName: 'شركة جديدة',
        englishName: 'New Shipping Co.',
        logoPath: r'C:\company\logo.png',
        signature1Label: 'المستلم',
        signature2Label: 'المحاسب',
        signature3Label: '',
      );

      final decoded =
          jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>;
      final restored = CompanyProfile.fromJson(decoded);

      expect(restored.arabicName, profile.arabicName);
      expect(restored.englishName, profile.englishName);
      expect(restored.logoPath, profile.logoPath);
      expect(restored.receiptSignatureLabels, ['المستلم', 'المحاسب', '']);
    });

    test('round-trips the source invoice number on a receipt', () {
      const receipt = ReceiptVoucher(
        receiptNumber: 'R-2',
        sourceInvoiceNumber: 'INV-7',
      );

      final decoded =
          jsonDecode(jsonEncode(receipt.toJson())) as Map<String, dynamic>;
      final restored = ReceiptVoucher.fromJson(decoded);

      expect(restored.sourceInvoiceNumber, 'INV-7');
    });
  });

  group('AmountToWordsArabic', () {
    test('includes currency and wraps the amount with the standard phrase', () {
      final words = AmountToWordsArabic.convert(34484, 'USD');

      expect(words, contains('دولار أمريكي'));
      expect(words, contains('ألف'));
      expect(words, startsWith('فقط '));
      expect(words, endsWith('لا غير'));
    });

    test('includes minor units when the amount contains cents', () {
      final words = AmountToWordsArabic.convert(12.50, 'USD');

      expect(words, contains('سنت'));
    });

    test('handles formatted decimal input in the model parser', () {
      expect(parseAmount('34,484.00'), 34484);
    });
  });
}
