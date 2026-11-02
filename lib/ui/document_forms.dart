import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../data/local_database.dart';
import '../models/document_models.dart';
import '../services/amount_to_words.dart';
import '../services/pdf_service.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  final List<_ChargeEditors> _charges = [];
  String _currency = 'USD';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final key in const [
      'invoiceNumber',
      'invoiceDate',
      'billOfLadingNumber',
      'releaseMethod',
      'transportName',
      'voyageNumber',
      'portOfLoading',
      'portOfDischarge',
      'arrivalDate',
      'customerName',
      'customerNumber',
      'containerCount',
      'quantity',
      'weight',
      'weightUnit',
      'discount',
    ]) {
      _fields[key] = TextEditingController();
    }
    _fields['invoiceDate']!.text = _today();
    _fields['weightUnit']!.text = 'طن';
    _addCharge();
    for (final controller in _fields.values) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _addCharge() {
    final charge = _ChargeEditors();
    charge.payee.addListener(_refresh);
    charge.description.addListener(_refresh);
    charge.amount.addListener(_refresh);
    _charges.add(charge);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final charge in _charges) {
      charge.dispose();
    }
    super.dispose();
  }

  ShippingInvoice _collect() => ShippingInvoice(
    invoiceNumber: _value('invoiceNumber'),
    invoiceDate: _value('invoiceDate'),
    currency: _currency,
    billOfLadingNumber: _value('billOfLadingNumber'),
    releaseMethod: _value('releaseMethod'),
    transportName: _value('transportName'),
    voyageNumber: _value('voyageNumber'),
    portOfLoading: _value('portOfLoading'),
    portOfDischarge: _value('portOfDischarge'),
    arrivalDate: _value('arrivalDate'),
    customerName: _value('customerName'),
    customerNumber: _value('customerNumber'),
    containerCount: _value('containerCount'),
    quantity: _value('quantity'),
    weight: _value('weight'),
    weightUnit: _value('weightUnit'),
    chargeLines: _charges
        .map(
          (line) => ChargeLine(
            payee: line.payee.text.trim(),
            description: line.description.text.trim(),
            amount: line.amount.text.trim(),
          ),
        )
        .toList(),
    discount: _value('discount'),
  );

  String _value(String key) => _fields[key]!.text.trim();

  Future<void> _saveRecord() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await widget.database.saveInvoice(_collect());
      if (mounted) _message('تم حفظ الفاتورة محليًا');
    } catch (error) {
      if (mounted) _message('تعذر حفظ الفاتورة: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = _collect();
    final bytes = await PdfService.invoice(data);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _PdfPreviewDialog(bytes: bytes, title: 'معاينة فاتورة الشحن'),
    );
  }

  Future<void> _savePdf() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = _collect();
    setState(() => _busy = true);
    try {
      await widget.database.saveInvoice(data);
      final bytes = await PdfService.invoice(data);
      final fileName = 'فاتورة-شحن-${_safeName(data.invoiceNumber)}.pdf';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: fileName,
      ).saveTo(location.path);
      if (mounted) _message('تم حفظ ملف PDF');
    } catch (error) {
      if (mounted) _message('تعذر إنشاء PDF: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = _collect();
    await widget.database.saveInvoice(data);
    await Printing.layoutPdf(onLayout: (_) => PdfService.invoice(data));
  }

  Future<void> _openSaved() async {
    final entries = await widget.database.recentInvoices();
    if (!mounted) return;
    final selected = await showDialog<ShippingInvoice>(
      context: context,
      builder: (context) => _SavedDocumentsDialog<ShippingInvoice>(
        title: 'الفواتير المحفوظة',
        emptyText: 'لا توجد فواتير محفوظة بعد',
        entries: entries,
        titleOf: (item) => 'فاتورة رقم ${item.invoiceNumber}',
        subtitleOf: (item) => '${item.customerName}  •  ${item.invoiceDate}',
      ),
    );
    if (selected != null) _load(selected);
  }

  void _load(ShippingInvoice data) {
    final values = <String, String>{
      'invoiceNumber': data.invoiceNumber,
      'invoiceDate': data.invoiceDate,
      'billOfLadingNumber': data.billOfLadingNumber,
      'releaseMethod': data.releaseMethod,
      'transportName': data.transportName,
      'voyageNumber': data.voyageNumber,
      'portOfLoading': data.portOfLoading,
      'portOfDischarge': data.portOfDischarge,
      'arrivalDate': data.arrivalDate,
      'customerName': data.customerName,
      'customerNumber': data.customerNumber,
      'containerCount': data.containerCount,
      'quantity': data.quantity,
      'weight': data.weight,
      'weightUnit': data.weightUnit,
      'discount': data.discount,
    };
    for (final entry in values.entries) {
      _fields[entry.key]!.text = entry.value;
    }
    for (final line in _charges) {
      line.dispose();
    }
    _charges
      ..clear()
      ..addAll(data.chargeLines.map(_ChargeEditors.fromLine));
    if (_charges.isEmpty) _addCharge();
    for (final charge in _charges) {
      charge.payee.addListener(_refresh);
      charge.description.addListener(_refresh);
      charge.amount.addListener(_refresh);
    }
    setState(() => _currency = data.currency);
  }

  @override
  Widget build(BuildContext context) {
    final data = _collect();
    return _PageFrame(
      title: 'بيانات الفاتورة',
      subtitle: 'أدخل بيانات الشحنة ثم راجع الفاتورة قبل طباعتها أو حفظها PDF.',
      actions: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _openSaved,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('فتح محفوظ'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _preview,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('معاينة'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _print,
          icon: const Icon(Icons.print_outlined),
          label: const Text('طباعة'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _savePdf,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('حفظ PDF'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _saveRecord,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ سجل'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormSection(
              title: 'البيانات الأساسية',
              icon: Icons.description_outlined,
              child: _formGrid([
                _input('رقم الفاتورة', 'invoiceNumber', required: true),
                _input('تاريخ الفاتورة', 'invoiceDate', required: true),
                _currencyDropdown(
                  _currency,
                  (value) => setState(() => _currency = value),
                ),
              ]),
            ),
            _FormSection(
              title: 'بيانات الشحنة',
              icon: Icons.local_shipping_outlined,
              child: _formGrid([
                _input('رقم البوليصة', 'billOfLadingNumber'),
                _input('طريقة الإفراج / أمر التسليم', 'releaseMethod'),
                _input('اسم وسيلة النقل', 'transportName'),
                _input('رقم الرحلة', 'voyageNumber'),
                _input('ميناء الشحن', 'portOfLoading'),
                _input('ميناء التفريغ', 'portOfDischarge'),
                _input('تاريخ الوصول', 'arrivalDate'),
              ]),
            ),
            _FormSection(
              title: 'بيانات العميل والحمولة',
              icon: Icons.person_outline,
              child: _formGrid([
                _input('اسم العميل', 'customerName', required: true),
                _input('رقم العميل', 'customerNumber'),
                _input('عدد الحاويات', 'containerCount'),
                _input('الكمية', 'quantity', keyboard: TextInputType.number),
                _input(
                  'الوزن',
                  'weight',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _input('وحدة الوزن', 'weightUnit'),
              ]),
            ),
            _FormSection(
              title: 'التفاصيل المالية',
              icon: Icons.calculate_outlined,
              trailing: TextButton.icon(
                onPressed: _addCharge,
                icon: const Icon(Icons.add),
                label: const Text('إضافة بند'),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _charges.length; i++)
                    _chargeEditor(_charges[i], i),
                  const SizedBox(height: 14),
                  _formGrid([
                    _input(
                      'الخصم',
                      'discount',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _readOnlyValue('الإجمالي قبل الخصم', _money(data.subtotal)),
                    _readOnlyValue(
                      'صافي المستحق',
                      _money(data.total),
                      emphasize: true,
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      AmountToWordsArabic.convert(data.total, _currency),
                      style: const TextStyle(
                        color: Color(0xFF9E3B3B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _chargeEditor(_ChargeEditors line, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _controllerField(
              'اسم المستحق',
              line.payee,
              required: index == 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: _controllerField('البيان', line.description),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _controllerField(
              'المبلغ',
              line.amount,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          IconButton(
            tooltip: 'حذف البند',
            onPressed: _charges.length == 1
                ? null
                : () {
                    setState(() => _charges.removeAt(index).dispose());
                  },
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Color(0xFFB34F4F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
    String label,
    String key, {
    bool required = false,
    TextInputType? keyboard,
  }) => _controllerField(
    label,
    _fields[key]!,
    required: required,
    keyboard: keyboard,
  );

  Widget _controllerField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    textAlign: TextAlign.right,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
        : null,
  );

  Widget _readOnlyValue(String label, String value, {bool emphasize = false}) =>
      TextFormField(
        initialValue: value,
        readOnly: true,
        key: ValueKey('$label-$value'),
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: emphasize
              ? const Color(0xFFEAF6FC)
              : const Color(0xFFF6F8FA),
        ),
        style: TextStyle(
          fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          color: emphasize ? const Color(0xFF153A5B) : null,
        ),
      );

  Widget _currencyDropdown(String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'العملة'),
        items: const [
          DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
          DropdownMenuItem(value: 'YER', child: Text('ريال يمني (YER)')),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      );

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error
            ? const Color(0xFF9E3B3B)
            : const Color(0xFF26735F),
      ),
    );
  }
}

class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  String _currency = 'USD';
  bool _busy = false;
  bool _updatingWords = false;

  @override
  void initState() {
    super.initState();
    for (final key in const [
      'receiptNumber',
      'receiptDate',
      'bankNumber',
      'customerName',
      'amount',
      'amountInWords',
      'bankName',
      'chequeNumber',
      'referenceNumber',
      'dueDate',
      'description',
    ]) {
      _fields[key] = TextEditingController();
    }
    _fields['receiptDate']!.text = _today();
    _fields['amount']!.addListener(_updateAmountWords);
  }

  void _updateAmountWords() {
    if (_updatingWords) return;
    _updatingWords = true;
    _fields['amountInWords']!.text = AmountToWordsArabic.convert(
      parseAmount(_fields['amount']!.text),
      _currency,
    );
    _updatingWords = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _fields[key]!.text.trim();

  ReceiptVoucher _collect() => ReceiptVoucher(
    receiptNumber: _value('receiptNumber'),
    receiptDate: _value('receiptDate'),
    bankNumber: _value('bankNumber'),
    customerName: _value('customerName'),
    amount: _value('amount'),
    currency: _currency,
    amountInWords: _value('amountInWords'),
    bankName: _value('bankName'),
    chequeNumber: _value('chequeNumber'),
    referenceNumber: _value('referenceNumber'),
    dueDate: _value('dueDate'),
    description: _value('description'),
  );

  Future<void> _saveRecord() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await widget.database.saveReceipt(_collect());
      if (mounted) _message('تم حفظ السند محليًا');
    } catch (error) {
      if (mounted) _message('تعذر حفظ السند: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bytes = await PdfService.receipt(_collect());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _PdfPreviewDialog(bytes: bytes, title: 'معاينة سند القبض'),
    );
  }

  Future<void> _savePdf() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = _collect();
    setState(() => _busy = true);
    try {
      await widget.database.saveReceipt(data);
      final bytes = await PdfService.receipt(data);
      final fileName = 'سند-قبض-${_safeName(data.receiptNumber)}.pdf';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: fileName,
      ).saveTo(location.path);
      if (mounted) _message('تم حفظ ملف PDF');
    } catch (error) {
      if (mounted) _message('تعذر إنشاء PDF: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = _collect();
    await widget.database.saveReceipt(data);
    await Printing.layoutPdf(onLayout: (_) => PdfService.receipt(data));
  }

  Future<void> _openSaved() async {
    final entries = await widget.database.recentReceipts();
    if (!mounted) return;
    final selected = await showDialog<ReceiptVoucher>(
      context: context,
      builder: (context) => _SavedDocumentsDialog<ReceiptVoucher>(
        title: 'سندات القبض المحفوظة',
        emptyText: 'لا توجد سندات محفوظة بعد',
        entries: entries,
        titleOf: (item) => 'سند رقم ${item.receiptNumber}',
        subtitleOf: (item) => '${item.customerName}  •  ${item.receiptDate}',
      ),
    );
    if (selected != null) _load(selected);
  }

  void _load(ReceiptVoucher data) {
    final values = <String, String>{
      'receiptNumber': data.receiptNumber,
      'receiptDate': data.receiptDate,
      'bankNumber': data.bankNumber,
      'customerName': data.customerName,
      'amount': data.amount,
      'amountInWords': data.amountInWords,
      'bankName': data.bankName,
      'chequeNumber': data.chequeNumber,
      'referenceNumber': data.referenceNumber,
      'dueDate': data.dueDate,
      'description': data.description,
    };
    setState(() => _currency = data.currency);
    for (final entry in values.entries) {
      _fields[entry.key]!.text = entry.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'بيانات سند القبض',
      subtitle: 'أدخل بيانات الشيك والمبلغ المستلم، وسيتم تحويل المبلغ إلى كلمات تلقائيًا.',
      actions: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _openSaved,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('فتح محفوظ'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _preview,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('معاينة'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _print,
          icon: const Icon(Icons.print_outlined),
          label: const Text('طباعة'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _savePdf,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('حفظ PDF'),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _saveRecord,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ سجل'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormSection(
              title: 'بيانات السند',
              icon: Icons.receipt_outlined,
              child: _formGrid([
                _input('رقم السند', 'receiptNumber', required: true),
                _input('تاريخ السند', 'receiptDate', required: true),
                _input('رقم البنك', 'bankNumber'),
                _input(
                  'استلمنا من (اسم العميل)',
                  'customerName',
                  required: true,
                ),
                _input(
                  'المبلغ بالأرقام',
                  'amount',
                  required: true,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _currencyDropdown(_currency, (value) {
                  setState(() => _currency = value);
                  _updateAmountWords();
                }),
              ]),
            ),
            _FormSection(
              title: 'بيانات الشيك',
              icon: Icons.account_balance_outlined,
              child: _formGrid([
                _input('اسم البنك', 'bankName'),
                _input('رقم الشيك', 'chequeNumber'),
                _input('رقم المرجع', 'referenceNumber'),
                _input('تاريخ الاستحقاق', 'dueDate'),
              ]),
            ),
            _FormSection(
              title: 'تفاصيل المبلغ',
              icon: Icons.notes_outlined,
              child: Column(
                children: [
                  _formGrid([
                    _input('البيان', 'description'),
                    _controllerInput(
                      'المبلغ تفقيطًا',
                      _fields['amountInWords']!,
                      maxLines: 2,
                    ),
                    _readOnlyValue(
                      'ملخص المبلغ',
                      '${_money(parseAmount(_value('amount')))} ${_currency == 'USD' ? 'دولار أمريكي' : 'ريال يمني'}',
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _value('amountInWords'),
                      style: const TextStyle(
                        color: Color(0xFF9E3B3B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _input(
    String label,
    String key, {
    bool required = false,
    TextInputType? keyboard,
  }) => _controllerInput(
    label,
    _fields[key]!,
    required: required,
    keyboard: keyboard,
  );

  Widget _controllerInput(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    maxLines: maxLines,
    textAlign: TextAlign.right,
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: maxLines > 1,
    ),
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
        : null,
  );

  Widget _readOnlyValue(String label, String value) => TextFormField(
    initialValue: value,
    readOnly: true,
    key: ValueKey('$label-$value'),
    textAlign: TextAlign.right,
    decoration: InputDecoration(
      labelText: label,
      fillColor: const Color(0xFFF6F8FA),
    ),
  );

  Widget _currencyDropdown(String value, ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'العملة'),
        items: const [
          DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
          DropdownMenuItem(value: 'YER', child: Text('ريال يمني (YER)')),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      );

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error
            ? const Color(0xFF9E3B3B)
            : const Color(0xFF26735F),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.child,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF637587),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Wrap(spacing: 7, runSpacing: 7, children: actions),
                  ],
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2F668C), size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

Widget _formGrid(List<Widget> fields) => LayoutBuilder(
  builder: (context, constraints) {
    final columns = constraints.maxWidth >= 900
        ? 3
        : (constraints.maxWidth >= 580 ? 2 : 1);
    final gap = 12.0;
    final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: fields
          .map((field) => SizedBox(width: width, child: field))
          .toList(),
    );
  },
);

class _PdfPreviewDialog extends StatelessWidget {
  const _PdfPreviewDialog({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(22),
      child: SizedBox(
        width: 1050,
        height: 740,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PdfPreview(
                build: (_) async => bytes,
                canChangePageFormat: false,
                canChangeOrientation: false,
                allowPrinting: false,
                allowSharing: false,
                pdfFileName: 'shipping-document.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedDocumentsDialog<T> extends StatelessWidget {
  const _SavedDocumentsDialog({
    required this.title,
    required this.emptyText,
    required this.entries,
    required this.titleOf,
    required this.subtitleOf,
  });

  final String title;
  final String emptyText;
  final List<T> entries;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        height: 400,
        child: entries.isEmpty
            ? Center(child: Text(emptyText))
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text(titleOf(entry)),
                    subtitle: Text(subtitleOf(entry)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.pop(context, entry),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _ChargeEditors {
  _ChargeEditors()
    : payee = TextEditingController(),
      description = TextEditingController(),
      amount = TextEditingController();

  _ChargeEditors.fromLine(ChargeLine line)
    : payee = TextEditingController(text: line.payee),
      description = TextEditingController(text: line.description),
      amount = TextEditingController(text: line.amount);

  final TextEditingController payee;
  final TextEditingController description;
  final TextEditingController amount;

  void dispose() {
    payee.dispose();
    description.dispose();
    amount.dispose();
  }
}

class _DateFormatter {
  static String today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
}

String _today() => _DateFormatter.today();
String _money(double amount) => amount.toStringAsFixed(2);
String _safeName(String value) =>
    value.replaceAll(RegExp(r'[^\w\-]'), '_').trim().isEmpty
    ? 'document'
    : value.replaceAll(RegExp(r'[^\w\-]'), '_');
