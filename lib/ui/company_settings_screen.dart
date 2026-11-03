import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/local_database.dart';
import '../models/document_models.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({
    required this.database,
    this.onSaved,
    super.key,
  });

  final LocalDatabase database;
  final ValueChanged<CompanyProfile>? onSaved;

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _busy = false;
  String _logoPath = '';

  static const _arabicFields = [
    _SettingsField('arabicName', 'اسم الشركة'),
    _SettingsField('arabicCountry', 'الدولة'),
    _SettingsField('arabicAddress', 'العنوان'),
    _SettingsField('arabicPhone', 'الهاتف'),
    _SettingsField('arabicFax', 'الفاكس'),
    _SettingsField('arabicPostBox', 'صندوق البريد'),
    _SettingsField('arabicExtraLine', 'سطر إضافي'),
  ];

  static const _englishFields = [
    _SettingsField('englishName', 'Company name', english: true),
    _SettingsField('englishCountry', 'Country', english: true),
    _SettingsField('englishAddress', 'Address', english: true),
    _SettingsField('englishPhone', 'Phone', english: true),
    _SettingsField('englishFax', 'Fax', english: true),
    _SettingsField('englishPostBox', 'Post box', english: true),
    _SettingsField('englishExtraLine', 'Extra line', english: true),
  ];

  static const _documentFields = [
    _SettingsField('invoiceTitle', 'عنوان الفاتورة'),
    _SettingsField('receiptTitle', 'عنوان السند'),
  ];

  static const _signatureFields = [
    _SettingsField('signature1Label', 'التوقيع الأول'),
    _SettingsField('signature2Label', 'التوقيع الثاني'),
    _SettingsField('signature3Label', 'التوقيع الثالث'),
  ];

  @override
  void initState() {
    super.initState();
    final keys = <String>{
      ..._arabicFields.map((field) => field.key),
      ..._englishFields.map((field) => field.key),
      ..._documentFields.map((field) => field.key),
      ..._signatureFields.map((field) => field.key),
    };
    for (final key in keys) {
      _controllers[key] = TextEditingController();
    }
    _loadProfile();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.database.getCompanyProfile();
      if (!mounted) return;
      _fillControllers(profile);
      setState(() {
        _logoPath = profile.logoPath;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('تعذر تحميل إعدادات الشركة: $error', error: true);
    }
  }

  void _fillControllers(CompanyProfile profile) {
    final values = <String, String>{
      'arabicName': profile.arabicName,
      'arabicCountry': profile.arabicCountry,
      'arabicAddress': profile.arabicAddress,
      'arabicPhone': profile.arabicPhone,
      'arabicFax': profile.arabicFax,
      'arabicPostBox': profile.arabicPostBox,
      'arabicExtraLine': profile.arabicExtraLine,
      'englishName': profile.englishName,
      'englishCountry': profile.englishCountry,
      'englishAddress': profile.englishAddress,
      'englishPhone': profile.englishPhone,
      'englishFax': profile.englishFax,
      'englishPostBox': profile.englishPostBox,
      'englishExtraLine': profile.englishExtraLine,
      'invoiceTitle': profile.invoiceTitle,
      'receiptTitle': profile.receiptTitle,
      'signature1Label': profile.signature1Label,
      'signature2Label': profile.signature2Label,
      'signature3Label': profile.signature3Label,
    };
    for (final entry in values.entries) {
      _controllers[entry.key]!.text = entry.value;
    }
  }

  CompanyProfile _collectProfile() => CompanyProfile(
    arabicName: _value('arabicName'),
    arabicCountry: _value('arabicCountry'),
    arabicAddress: _value('arabicAddress'),
    arabicPhone: _value('arabicPhone'),
    arabicFax: _value('arabicFax'),
    arabicPostBox: _value('arabicPostBox'),
    arabicExtraLine: _value('arabicExtraLine'),
    englishName: _value('englishName'),
    englishCountry: _value('englishCountry'),
    englishAddress: _value('englishAddress'),
    englishPhone: _value('englishPhone'),
    englishFax: _value('englishFax'),
    englishPostBox: _value('englishPostBox'),
    englishExtraLine: _value('englishExtraLine'),
    invoiceTitle: _value('invoiceTitle'),
    receiptTitle: _value('receiptTitle'),
    logoPath: _logoPath,
    signature1Label: _value('signature1Label'),
    signature2Label: _value('signature2Label'),
    signature3Label: _value('signature3Label'),
  );

  String _value(String key) => _controllers[key]!.text.trim();

  Future<void> _save() async {
    if (_loading || _busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      final profile = _collectProfile();
      await widget.database.saveCompanyProfile(profile);
      if (!mounted) return;
      widget.onSaved?.call(profile);
      _showMessage('تم حفظ إعدادات الشركة محليًا');
    } catch (error) {
      if (mounted) _showMessage('تعذر حفظ إعدادات الشركة: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickLogo() async {
    if (_busy) return;
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Images', extensions: ['png', 'jpg', 'jpeg']),
      ],
    );
    if (selected == null) {
      return;
    }

    final extension = p.extension(selected.path).toLowerCase();
    const allowedExtensions = {'.png', '.jpg', '.jpeg'};
    if (!allowedExtensions.contains(extension)) {
      if (mounted) {
        _showMessage('يرجى اختيار صورة PNG أو JPG أو JPEG', error: true);
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final directory = Directory(LocalDatabase.applicationDataPath());
      await directory.create(recursive: true);
      final targetPath = p.join(directory.path, 'company_logo$extension');
      final bytes = await selected.readAsBytes();
      await File(targetPath).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _logoPath = targetPath);
      _showMessage('تم اختيار شعار الشركة');
    } catch (error) {
      if (mounted) _showMessage('تعذر حفظ الشعار محليًا: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeLogo() {
    if (_busy) return;
    setState(() => _logoPath = '');
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB3261E) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الشركة'),
          backgroundColor: const Color(0xFF153A5B),
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _introCard(),
                            const SizedBox(height: 16),
                            _section('الترويسة العربية', _arabicFields),
                            const SizedBox(height: 16),
                            _section('الترويسة الإنجليزية', _englishFields),
                            const SizedBox(height: 16),
                            _section('عناوين المستندات', _documentFields),
                            const SizedBox(height: 16),
                            _section('تسميات التوقيعات', _signatureFields),
                            const SizedBox(height: 16),
                            _logoSection(),
                            const SizedBox(height: 24),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _save,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('حفظ الإعدادات'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _introCard() => Card(
    color: const Color(0xFFEAF2F7),
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF153A5B)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تُستخدم هذه البيانات في ترويسة الفواتير وسندات القبض والتوقيعات. تُحفظ الإعدادات والشعار على هذا الجهاز فقط.',
              style: TextStyle(color: Color(0xFF173A59)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _section(String title, List<_SettingsField> fields) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF173A59),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 14,
                children: fields
                    .map(
                      (field) => SizedBox(width: width, child: _field(field)),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _field(_SettingsField field) => TextFormField(
    controller: _controllers[field.key],
    textDirection: field.english ? TextDirection.ltr : TextDirection.rtl,
    textAlign: field.english ? TextAlign.left : TextAlign.right,
    decoration: InputDecoration(
      labelText: field.label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );

  Widget _logoSection() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'شعار الشركة',
            style: TextStyle(
              color: Color(0xFF173A59),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 180, height: 140, child: _logoPreview()),
              SizedBox(
                width: 330,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر صورة PNG أو JPG أو JPEG. سيتم نسخها إلى مجلد بيانات التطبيق باسم آمن.',
                      style: TextStyle(color: Color(0xFF637587)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pickLogo,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('اختيار شعار'),
                        ),
                        if (_logoPath.isNotEmpty)
                          TextButton.icon(
                            onPressed: _busy ? null : _removeLogo,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('إزالة الشعار'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _logoPreview() {
    final hasLogo = _logoPath.isNotEmpty && File(_logoPath).existsSync();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F8),
        border: Border.all(color: const Color(0xFFD7E0E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: hasLogo
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.file(
                File(_logoPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const _EmptyLogo(),
              ),
            )
          : const _EmptyLogo(),
    );
  }
}

class _SettingsField {
  const _SettingsField(this.key, this.label, {this.english = false});

  final String key;
  final String label;
  final bool english;
}

class _EmptyLogo extends StatelessWidget {
  const _EmptyLogo();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.business_outlined, size: 48, color: Color(0xFF9AAAB7)),
  );
}
