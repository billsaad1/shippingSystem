import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/document_models.dart';
import 'amount_to_words.dart';

class PdfService {
  static const _blue = PdfColor.fromInt(0xFFB7DDF8);
  static const _paleBlue = PdfColor.fromInt(0xFFEAF6FC);
  static const _red = PdfColor.fromInt(0xFF9E3B3B);

  static Future<Uint8List> invoice(ShippingInvoice data) async {
    final assets = await _loadAssets();
    final document = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: assets.regular,
      bold: assets.bold,
      fontFallback: [assets.latinRegular, assets.latinBold],
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(18),
        theme: theme,
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _companyHeader(assets, title: 'فاتورة أجور شحن'),
              pw.SizedBox(height: 7),
              _invoiceTopLine(data, assets),
              pw.SizedBox(height: 4),
              _invoiceDetails(data, assets),
              pw.SizedBox(height: 5),
              _invoiceCharges(data, assets),
              pw.SizedBox(height: 4),
              _invoiceTotals(data),
              pw.SizedBox(height: 4),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _paleBlue,
                  border: pw.Border.all(color: PdfColors.black, width: 0.5),
                ),
                child: _text(
                  AmountToWordsArabic.convert(data.total, data.currency),
                  assets,
                  size: 9,
                  color: _red,
                  bold: true,
                  align: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static Future<Uint8List> receipt(ReceiptVoucher data) async {
    final assets = await _loadAssets();
    final document = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: assets.regular,
      bold: assets.bold,
      fontFallback: [assets.latinRegular, assets.latinBold],
    );

    document.addPage(
      pw.Page(
        // Both originals are landscape; the receipt sample was photographed
        // with the phone held in portrait orientation.
        pageFormat: PdfPageFormat.a5.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(17),
        theme: theme,
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _companyHeader(assets, title: 'سند قبض - شيك'),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _receiptDetails([
                      ('رقم السند', data.receiptNumber),
                      ('تاريخ السند', data.receiptDate),
                      ('رقم البنك', data.bankNumber),
                      ('استلمنا من', data.customerName),
                    ], assets),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: _receiptDetails([
                      ('اسم البنك', data.bankName),
                      ('رقم الشيك', data.chequeNumber),
                      ('رقم المرجع', data.referenceNumber),
                      ('تاريخ الاستحقاق', data.dueDate),
                    ], assets),
                  ),
                ],
              ),
              pw.SizedBox(height: 7),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  color: _paleBlue,
                  border: pw.Border.all(color: PdfColors.black, width: 0.6),
                ),
                child: pw.Row(
                  children: [
                    _text('المبلغ:', assets, size: 10, bold: true),
                    pw.SizedBox(width: 6),
                    _textLtr(
                      _formatAmount(data.numericAmount),
                      assets,
                      size: 12,
                      bold: true,
                      color: _red,
                    ),
                    pw.SizedBox(width: 4),
                    _text(
                      _currencyLabel(data.currency),
                      assets,
                      size: 10,
                      bold: true,
                      color: _red,
                    ),
                    pw.Spacer(),
                    _text('البيان:', assets, size: 10, bold: true),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      flex: 3,
                      child: _text(
                        data.description,
                        assets,
                        size: 10,
                        align: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                child: _text(
                  data.amountInWords.trim().isEmpty
                      ? AmountToWordsArabic.convert(
                          data.numericAmount,
                          data.currency,
                        )
                      : data.amountInWords,
                  assets,
                  size: 9,
                  color: _red,
                  bold: true,
                  align: pw.TextAlign.right,
                ),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _signature('المستلم', assets),
                  _signature('المراجع', assets),
                  _signature('مدير الحسابات', assets),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static Future<_PdfAssets> _loadAssets() async {
    final regularData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );
    final boldData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    );
    final latinRegularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final latinBoldData = await rootBundle.load(
      'assets/fonts/NotoSans-Bold.ttf',
    );
    final markData = await rootBundle.load('assets/images/company_mark.png');
    return _PdfAssets(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
      latinRegular: pw.Font.ttf(latinRegularData),
      latinBold: pw.Font.ttf(latinBoldData),
      mark: pw.MemoryImage(markData.buffer.asUint8List()),
    );
  }

  static pw.Widget _companyHeader(_PdfAssets assets, {required String title}) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.7),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _text(
                      'شركة الهلال للملاحة اليمن المحدودة - فرع عدن',
                      assets,
                      size: 11,
                      bold: true,
                      align: pw.TextAlign.right,
                    ),
                    _text(
                      'الجمهورية اليمنية',
                      assets,
                      size: 10,
                      bold: true,
                      align: pw.TextAlign.right,
                    ),
                    _text(
                      'عدن - شارع المعلا - دكة',
                      assets,
                      size: 10,
                      bold: true,
                      align: pw.TextAlign.right,
                    ),
                    pw.Row(
                      children: [
                        _text('رقم التلفون:', assets, size: 9),
                        pw.SizedBox(width: 2),
                        _textLtr('02-221844', assets, size: 9),
                        pw.SizedBox(width: 6),
                        _text('رقم الفاكس:', assets, size: 9),
                        pw.SizedBox(width: 2),
                        _textLtr('02-247844', assets, size: 9),
                      ],
                    ),
                    _text(
                      'رقم البريد: 3147',
                      assets,
                      size: 9,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 48,
                height: 56,
                child: pw.Image(assets.mark, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _english(
                      'Alhalal Shipping co (Yemen) Ltd',
                      assets,
                      bold: true,
                    ),
                    _english('Republic of Yemen', assets),
                    _english('Aden - Al-Mualla Street', assets),
                    _english('Tel: 02-221844   Fax: 02-247844', assets),
                    _english('P.O. Box: 3147', assets),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 230,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 15),
          decoration: pw.BoxDecoration(
            color: _blue,
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: _text(
            title,
            assets,
            size: 12,
            bold: true,
            align: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  static pw.Widget _invoiceTopLine(ShippingInvoice data, _PdfAssets assets) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.6),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _inlineField('رقم الفاتورة', data.invoiceNumber, assets),
          _inlineField('تاريخ الفاتورة', data.invoiceDate, assets),
          _inlineField(
            'العملة',
            _currencyCode(data.currency),
            assets,
            color: _red,
          ),
        ],
      ),
    );
  }

  static pw.Widget _inlineField(
    String label,
    String value,
    _PdfAssets assets, {
    PdfColor? color,
  }) => pw.Row(
    children: [
      _text('$label:', assets, size: 9, bold: true),
      pw.SizedBox(width: 3),
      _textValue(value, assets, size: 9, bold: true, color: color),
    ],
  );

  static pw.Widget _invoiceDetails(ShippingInvoice data, _PdfAssets assets) {
    final left = <(String, String)>[
      ('رقم البوليصة', data.billOfLadingNumber),
      ('اسم وسيلة النقل', data.transportName),
      ('عدد الحاويات', data.containerCount),
      ('الوزن', '${data.weight} ${data.weightUnit}'.trim()),
      ('اسم العميل', data.customerName),
    ];
    final right = <(String, String)>[
      ('رقم أمر التسليم', data.releaseMethod),
      ('رقم الرحلة', data.voyageNumber),
      ('ميناء الشحن', data.portOfLoading),
      ('ميناء التفريغ', data.portOfDischarge),
      ('تاريخ الوصول', data.arrivalDate),
      ('الكمية', data.quantity),
      ('رقم العميل', data.customerNumber),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _detailsColumn(right, assets)),
          pw.SizedBox(width: 14),
          pw.Expanded(child: _detailsColumn(left, assets)),
        ],
      ),
    );
  }

  static pw.Widget _detailsColumn(
    List<(String, String)> values,
    _PdfAssets assets,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: values
        .map(
          (item) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: _textRaw(
                    item.$1,
                    bold: true,
                    align: pw.TextAlign.right,
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Expanded(
                  child: _textValue(item.$2, assets, align: pw.TextAlign.right),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );

  static pw.Widget _invoiceCharges(ShippingInvoice data, _PdfAssets assets) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _blue),
        children: [
          _tableCell('المبلغ', assets, bold: true),
          _tableCell('البيان', assets, bold: true),
          _tableCell('اسم المستحق', assets, bold: true),
          _tableCell('رقم المستحق', assets, bold: true),
        ],
      ),
    ];
    final lines = data.chargeLines.isEmpty
        ? const [ChargeLine()]
        : data.chargeLines;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      rows.add(
        pw.TableRow(
          children: [
            _tableCell(_formatAmount(line.numericAmount), assets),
            _tableCell(line.description, assets),
            _tableCell(line.payee, assets),
            _tableCell('${index + 1}', assets),
          ],
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(3.5),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FlexColumnWidth(0.8),
      },
      children: rows,
    );
  }

  static pw.Widget _tableCell(
    String value,
    _PdfAssets assets, {
    bool bold = false,
  }) => pw.Container(
    height: 19,
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: _textValue(value, assets, bold: bold, align: pw.TextAlign.center),
  );

  static pw.Widget _invoiceTotals(ShippingInvoice data) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.black, width: 0.5),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(child: _summary('الإجمالي', data.subtotal)),
        pw.Expanded(child: _summary('الخصم', data.discountValue)),
        pw.Expanded(child: _summary('الصافي', data.total, red: true)),
        pw.Expanded(
          child: _textRaw(
            _currencyLabel(data.currency),
            bold: true,
            align: pw.TextAlign.center,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _summary(String label, double value, {bool red = false}) =>
      pw.Column(
        children: [
          _textRaw(label, bold: true, align: pw.TextAlign.center),
          _textRaw(
            _formatAmount(value),
            bold: true,
            color: red ? _red : null,
            align: pw.TextAlign.center,
          ),
        ],
      );

  static pw.Widget _receiptDetails(
    List<(String, String)> values,
    _PdfAssets assets,
  ) => pw.Column(
    children: values.map((item) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.4),
          ),
        ),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 92,
              child: _text(item.$1, assets, size: 9, bold: true),
            ),
            pw.Expanded(
              child: _textValue(
                item.$2,
                assets,
                size: 9,
                align: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );

  static pw.Widget _signature(String title, _PdfAssets assets) => pw.Container(
    width: 95,
    padding: const pw.EdgeInsets.only(top: 5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey700, width: 0.5),
      ),
    ),
    child: _text(title, assets, size: 8, align: pw.TextAlign.center),
  );

  static pw.Widget _text(
    String value,
    _PdfAssets assets, {
    double size = 9,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) => pw.Text(
    value,
    textDirection: pw.TextDirection.rtl,
    textAlign: align,
    style: pw.TextStyle(
      font: bold ? assets.bold : assets.regular,
      fontFallback: [assets.latinRegular, assets.latinBold],
      fontSize: size,
      color: color ?? PdfColors.black,
    ),
  );

  static pw.Widget _textValue(
    String value,
    _PdfAssets assets, {
    double size = 9,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    final isAscii =
        value.trim().isNotEmpty && RegExp(r'^[\x00-\x7F]+$').hasMatch(value);
    if (isAscii) {
      return _textLtr(
        value,
        assets,
        size: size,
        bold: bold,
        color: color,
        align: align,
      );
    }
    return _text(
      value,
      assets,
      size: size,
      bold: bold,
      color: color,
      align: align,
    );
  }

  static pw.Widget _textLtr(
    String value,
    _PdfAssets assets, {
    double size = 9,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) => pw.Text(
    value,
    textDirection: pw.TextDirection.ltr,
    textAlign: align,
    style: pw.TextStyle(
      font: bold ? assets.latinBold : assets.latinRegular,
      fontFallback: [assets.regular, assets.bold],
      fontSize: size,
      color: color ?? PdfColors.black,
    ),
  );

  static pw.Widget _textRaw(
    String value, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) => pw.Text(
    value,
    textDirection: pw.TextDirection.rtl,
    textAlign: align,
    style: pw.TextStyle(
      fontSize: 8.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? PdfColors.black,
    ),
  );

  static pw.Widget _english(
    String value,
    _PdfAssets assets, {
    bool bold = false,
  }) => pw.Text(
    value,
    textDirection: pw.TextDirection.ltr,
    textAlign: pw.TextAlign.left,
    style: pw.TextStyle(
      font: bold ? assets.latinBold : assets.latinRegular,
      fontFallback: [assets.regular, assets.bold],
      fontSize: 8.5,
    ),
  );

  static String _formatAmount(double value) => value.toStringAsFixed(2);

  static String _currencyCode(String currency) =>
      currency.toUpperCase() == 'USD' ? 'USD' : 'YER';

  static String _currencyLabel(String currency) =>
      currency.toUpperCase() == 'USD' ? 'دولار أمريكي' : 'ريال يمني';
}

class _PdfAssets {
  const _PdfAssets({
    required this.regular,
    required this.bold,
    required this.latinRegular,
    required this.latinBold,
    required this.mark,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font latinRegular;
  final pw.Font latinBold;
  final pw.ImageProvider mark;
}
