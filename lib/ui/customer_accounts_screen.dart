import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models/customer_models.dart';
import '../services/money_minor_units.dart';

class CustomerAccountsScreen extends StatefulWidget {
  const CustomerAccountsScreen({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<CustomerAccountsScreen> createState() => _CustomerAccountsScreenState();
}

class _CustomerAccountsScreenState extends State<CustomerAccountsScreen> {
  final _searchController = TextEditingController();
  List<CustomerAccountSummary> _accounts = const [];
  bool _loading = true;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_reload)
      ..dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final accounts = await widget.database.customerAccounts(
        search: _searchController.text,
        includeInactive: _showInactive,
      );
      if (mounted) setState(() => _accounts = accounts);
    } catch (error) {
      if (mounted) _message('تعذر تحميل قائمة العملاء: $error', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCustomer([Customer? customer]) async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => _CustomerEditorDialog(customer: customer),
    );
    if (result == null) return;
    try {
      await widget.database.saveCustomer(result);
      await _reload();
      if (mounted) {
        _message(
          customer == null ? 'تمت إضافة العميل' : 'تم تحديث بيانات العميل',
        );
      }
    } catch (error) {
      if (mounted) _message('تعذر حفظ العميل: $error', error: true);
    }
  }

  Future<void> _openStatement(CustomerAccountSummary account) async {
    final customer = account.customer;
    if (customer.id == null) return;
    final entries = await widget.database.customerStatement(customer.id!);
    final balances = await widget.database.customerBalances(customer.id!);
    final openInvoices = await widget.database.customerOpenInvoices(
      customer.id!,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _CustomerStatementDialog(
        customer: customer,
        entries: entries,
        balances: balances,
        openInvoices: openInvoices,
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final usdTotal = _accounts.fold<int>(
      0,
      (sum, account) => sum + account.usdBalanceMinor,
    );
    final yerTotal = _accounts.fold<int>(
      0,
      (sum, account) => sum + account.yerBalanceMinor,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_outlined, color: Color(0xFF153A5B)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'العملاء والحسابات',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'تُحدّث أرصدة العملاء تلقائيًا من الفواتير وسندات القبض المحفوظة.',
                      style: TextStyle(color: Color(0xFF637587)),
                    ),
                  ],
                ),
              ),
              FilterChip(
                selected: _showInactive,
                label: const Text('عرض الموقوفين'),
                onSelected: (value) {
                  setState(() => _showInactive = value);
                  _reload();
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('add-customer-button'),
                onPressed: () => _editCustomer(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('إضافة عميل'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _SummaryChip(
                icon: Icons.people_outline,
                label: 'العملاء',
                value: _accounts.length.toString(),
              ),
              _SummaryChip(
                icon: Icons.attach_money,
                label: 'صافي الذمم USD',
                value: MoneyMinorUnits.format(usdTotal),
              ),
              _SummaryChip(
                icon: Icons.currency_exchange,
                label: 'صافي الذمم YER',
                value: MoneyMinorUnits.format(yerTotal),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('customer-search-field'),
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو رقم العميل أو الهاتف',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _accounts.isEmpty
                ? const _EmptyCustomers()
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.separated(
                      key: const ValueKey('customer-account-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _accounts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final account = _accounts[index];
                        return _CustomerAccountCard(
                          account: account,
                          onTap: () => _openStatement(account),
                          onEdit: () => _editCustomer(account.customer),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3F8),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF27658D)),
        const SizedBox(width: 7),
        Text('$label: ', style: const TextStyle(color: Color(0xFF566A7A))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _CustomerAccountCard extends StatelessWidget {
  const _CustomerAccountCard({
    required this.account,
    required this.onTap,
    required this.onEdit,
  });

  final CustomerAccountSummary account;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final customer = account.customer;
    final details = [
      if (!customer.isActive) 'موقوف',
      if (customer.customerNumber.isNotEmpty) 'رقم ${customer.customerNumber}',
      if (customer.phone.isNotEmpty) customer.phone,
    ].join(' • ');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2EAF0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEAF3F8),
                foregroundColor: Color(0xFF27658D),
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.isEmpty ? 'اضغط لعرض كشف الحساب' : details,
                      style: const TextStyle(
                        color: Color(0xFF637587),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _BalanceBadge(currency: 'USD', amount: account.usdBalanceMinor),
              const SizedBox(width: 8),
              _BalanceBadge(currency: 'YER', amount: account.yerBalanceMinor),
              IconButton(
                tooltip: 'تعديل بيانات العميل',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({required this.currency, required this.amount});

  final String currency;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final isCredit = amount < 0;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isCredit ? const Color(0xFFFFF4E5) : const Color(0xFFF0F6F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currency,
            style: const TextStyle(fontSize: 10, color: Color(0xFF637587)),
          ),
          Text(
            MoneyMinorUnits.format(amount.abs()),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isCredit
                  ? const Color(0xFF98631A)
                  : const Color(0xFF26735F),
            ),
          ),
          Text(
            isCredit ? 'رصيد دائن' : 'رصيد مدين',
            style: const TextStyle(fontSize: 9, color: Color(0xFF637587)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.groups_outlined, size: 48, color: Color(0xFF9AAAB7)),
        const SizedBox(height: 10),
        const Text('لا توجد بطاقات عملاء بعد'),
        const SizedBox(height: 4),
        Text(
          'سيُضاف العميل تلقائيًا عند حفظ أول فاتورة له.',
          style: TextStyle(color: Colors.blueGrey.shade500),
        ),
      ],
    ),
  );
}

class _CustomerEditorDialog extends StatefulWidget {
  const _CustomerEditorDialog({this.customer});

  final Customer? customer;

  @override
  State<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<_CustomerEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer ?? const Customer(name: '');
    _fields = {
      'customerNumber': TextEditingController(text: customer.customerNumber),
      'name': TextEditingController(text: customer.name),
      'englishName': TextEditingController(text: customer.englishName),
      'phone': TextEditingController(text: customer.phone),
      'email': TextEditingController(text: customer.email),
      'address': TextEditingController(text: customer.address),
      'notes': TextEditingController(text: customer.notes),
    };
    _isActive = customer.isActive;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.customer == null ? 'إضافة عميل' : 'تعديل بيانات العميل'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('رقم العميل', 'customerNumber'),
              _field('اسم العميل', 'name', required: true),
              _field('الاسم بالإنجليزية', 'englishName'),
              _field('رقم الهاتف', 'phone', keyboard: TextInputType.phone),
              _field(
                'البريد الإلكتروني',
                'email',
                keyboard: TextInputType.emailAddress,
              ),
              _field('العنوان', 'address'),
              _field('ملاحظات', 'notes', maxLines: 2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('العميل نشط'),
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            Customer(
              id: widget.customer?.id,
              customerNumber: _fields['customerNumber']!.text.trim(),
              name: _fields['name']!.text.trim(),
              englishName: _fields['englishName']!.text.trim(),
              phone: _fields['phone']!.text.trim(),
              email: _fields['email']!.text.trim(),
              address: _fields['address']!.text.trim(),
              notes: _fields['notes']!.text.trim(),
              isActive: _isActive,
              createdAt: widget.customer?.createdAt ?? '',
            ),
          );
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('حفظ'),
      ),
    ],
  );

  Widget _field(
    String label,
    String key, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: TextFormField(
      controller: _fields[key],
      keyboardType: keyboard,
      maxLines: maxLines,
      key: ValueKey('customer-field-$key'),
      textAlign: TextAlign.right,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
          : null,
    ),
  );
}

class _CustomerStatementDialog extends StatelessWidget {
  const _CustomerStatementDialog({
    required this.customer,
    required this.entries,
    required this.balances,
    required this.openInvoices,
  });

  final Customer customer;
  final List<CustomerLedgerEntry> entries;
  final Map<String, int> balances;
  final List<CustomerInvoiceBalance> openInvoices;

  @override
  Widget build(BuildContext context) {
    final running = <String, int>{'USD': 0, 'YER': 0};
    final rows = <Widget>[];
    for (final entry in entries) {
      running[entry.currency] =
          (running[entry.currency] ?? 0) + entry.balanceChangeMinor;
      rows.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE8EDF1))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                child: Text(entry.entryDate, textDirection: TextDirection.ltr),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.sourceNumber}${entry.isLegacy ? ' • سجل سابق' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF758391),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 104,
                child: Text(
                  entry.debitMinor == 0
                      ? '—'
                      : MoneyMinorUnits.format(entry.debitMinor),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                ),
              ),
              SizedBox(
                width: 104,
                child: Text(
                  entry.creditMinor == 0
                      ? '—'
                      : MoneyMinorUnits.format(entry.creditMinor),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                ),
              ),
              SizedBox(
                width: 116,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      entry.currency,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF758391),
                      ),
                    ),
                    Text(
                      MoneyMinorUnits.format(running[entry.currency] ?? 0),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text('كشف حساب ${customer.name}'),
      content: SizedBox(
        width: 860,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              children: [
                _SummaryChip(
                  icon: Icons.attach_money,
                  label: 'الرصيد USD',
                  value: MoneyMinorUnits.format(balances['USD'] ?? 0),
                ),
                _SummaryChip(
                  icon: Icons.currency_exchange,
                  label: 'الرصيد YER',
                  value: MoneyMinorUnits.format(balances['YER'] ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.pending_actions_outlined),
              title: Text('الفواتير غير المسددة (${openInvoices.length})'),
              children: openInvoices.isEmpty
                  ? const [
                      ListTile(
                        title: Text('لا توجد فواتير مفتوحة على هذا العميل.'),
                      ),
                    ]
                  : [
                      for (final invoice in openInvoices)
                        ListTile(
                          dense: true,
                          title: Text('فاتورة ${invoice.invoiceNumber}'),
                          subtitle: Text(
                            'التاريخ ${invoice.invoiceDate} • الإجمالي ${MoneyMinorUnits.format(invoice.totalMinor)} • المسدد ${MoneyMinorUnits.format(invoice.paidMinor)} ${invoice.currency}',
                          ),
                          trailing: Text(
                            'المتبقي ${MoneyMinorUnits.format(invoice.outstandingMinor)} ${invoice.currency}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              color: const Color(0xFFEAF3F8),
              child: const Row(
                children: [
                  SizedBox(width: 92, child: Text('التاريخ')),
                  Expanded(flex: 4, child: Text('الحركة / المستند')),
                  SizedBox(
                    width: 104,
                    child: Text('مدين', textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 104,
                    child: Text('دائن', textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 116, child: Text('الرصيد')),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text('لا توجد حركات حساب لهذا العميل بعد.'),
                    )
                  : ListView(children: rows),
            ),
          ],
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

Future<Customer?> selectCustomerDialog(
  BuildContext context,
  LocalDatabase database,
) async {
  final customers = await database.customers();
  if (!context.mounted) return null;
  return showDialog<Customer>(
    context: context,
    builder: (context) => _CustomerPickerDialog(customers: customers),
  );
}

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({required this.customers});

  final List<Customer> customers;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final results = widget.customers.where((customer) {
      if (query.isEmpty) return true;
      return customer.name.toLowerCase().contains(query) ||
          customer.customerNumber.toLowerCase().contains(query) ||
          customer.phone.toLowerCase().contains(query);
    }).toList();
    return AlertDialog(
      title: const Text('اختيار عميل محفوظ'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: 'ابحث عن عميل',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text('لا يوجد عميل مطابق. أضفه من قائمة العملاء.'),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final customer = results[index];
                        return ListTile(
                          key: ValueKey('pick-customer-${customer.id}'),
                          leading: const Icon(Icons.person_outline),
                          title: Text(customer.name),
                          subtitle: Text(
                            [
                              if (customer.customerNumber.isNotEmpty)
                                customer.customerNumber,
                              if (customer.phone.isNotEmpty) customer.phone,
                            ].join(' • '),
                          ),
                          onTap: () => Navigator.pop(context, customer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
