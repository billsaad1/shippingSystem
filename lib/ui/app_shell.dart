import 'dart:io';

import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../models/document_models.dart';
import 'company_settings_screen.dart';
import 'customer_accounts_screen.dart';
import 'document_forms.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final ValueNotifier<ShippingInvoice?> _invoiceToImport;
  CompanyProfile _companyProfile = const CompanyProfile.defaults();

  @override
  void initState() {
    super.initState();
    _invoiceToImport = ValueNotifier(null);
    _loadCompanyProfile();
  }

  Future<void> _loadCompanyProfile() async {
    try {
      final profile = await widget.database.getCompanyProfile();
      if (mounted) setState(() => _companyProfile = profile);
    } catch (_) {
      // Keep the blank defaults available if a profile row cannot be read.
    }
  }

  @override
  void dispose() {
    _invoiceToImport.dispose();
    super.dispose();
  }

  void _createReceiptFromInvoice(ShippingInvoice invoice) {
    setState(() => _selectedIndex = 1);
    _invoiceToImport.value = invoice;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_selectedIndex) {
      0 => 'إصدار فاتورة شحن',
      1 => 'إصدار سند قبض',
      2 => 'إعدادات الشركة',
      _ => 'العملاء والحسابات',
    };
    return Scaffold(
      body: Row(
        children: [
          _SideNavigation(
            selectedIndex: _selectedIndex,
            companyProfile: _companyProfile,
            onSelect: (index) => setState(() => _selectedIndex = index),
          ),
          Expanded(
            child: Column(
              children: [
                if (_selectedIndex != 2) _TopBar(title: title),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      InvoiceFormScreen(
                        database: widget.database,
                        onCreateReceipt: _createReceiptFromInvoice,
                      ),
                      ReceiptFormScreen(
                        database: widget.database,
                        invoiceToImport: _invoiceToImport,
                      ),
                      if (_selectedIndex == 2)
                        CompanySettingsScreen(
                          database: widget.database,
                          onSaved: (profile) =>
                              setState(() => _companyProfile = profile),
                        )
                      else
                        const SizedBox.shrink(),
                      if (_selectedIndex == 3)
                        CustomerAccountsScreen(database: widget.database)
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selectedIndex,
    required this.companyProfile,
    required this.onSelect,
  });

  final int selectedIndex;
  final CompanyProfile companyProfile;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 235,
      color: const Color(0xFF153A5B),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child:
                  companyProfile.logoPath.trim().isNotEmpty &&
                      File(companyProfile.logoPath).existsSync()
                  ? Image.file(
                      File(companyProfile.logoPath),
                      fit: BoxFit.contain,
                    )
                  : const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF153A5B),
                      size: 38,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              companyProfile.arabicName.trim().isEmpty
                  ? 'نظام الشحن'
                  : companyProfile.arabicName.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'الفواتير والسندات',
              style: TextStyle(color: Color(0xFFBFD0DF), fontSize: 12),
            ),
            const SizedBox(height: 34),
            _NavigationButton(
              icon: Icons.receipt_long_outlined,
              label: 'فاتورة أجور الشحن',
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
            _NavigationButton(
              icon: Icons.payments_outlined,
              label: 'سند قبض - شيك',
              selected: selectedIndex == 1,
              onTap: () => onSelect(1),
            ),
            _NavigationButton(
              icon: Icons.business_outlined,
              label: 'بيانات الشركة',
              selected: selectedIndex == 2,
              onTap: () => onSelect(2),
            ),
            _NavigationButton(
              icon: Icons.groups_outlined,
              label: 'العملاء والحسابات',
              selected: selectedIndex == 3,
              onTap: () => onSelect(3),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'يتم حفظ البيانات على هذا الجهاز فقط',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFBFD0DF), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : const Color(0xFFBFD0DF),
                  size: 20,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFBFD0DF),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.chevron_left, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE6ECF1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF173A59),
              ),
            ),
          ),
          const Icon(
            Icons.offline_bolt_outlined,
            size: 18,
            color: Color(0xFF388A76),
          ),
          const SizedBox(width: 6),
          const Text(
            'يعمل دون اتصال',
            style: TextStyle(fontSize: 12, color: Color(0xFF637587)),
          ),
        ],
      ),
    );
  }
}
