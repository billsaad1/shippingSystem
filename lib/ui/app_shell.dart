import 'package:flutter/material.dart';

import '../data/local_database.dart';
import 'document_forms.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.database, super.key});

  final LocalDatabase database;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final title = _selectedIndex == 0 ? 'إصدار فاتورة شحن' : 'إصدار سند قبض';
    return Scaffold(
      body: Row(
        children: [
          _SideNavigation(
            selectedIndex: _selectedIndex,
            onSelect: (index) => setState(() => _selectedIndex = index),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: title),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      InvoiceFormScreen(database: widget.database),
                      ReceiptFormScreen(database: widget.database),
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
  const _SideNavigation({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
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
              child: Image.asset(
                'assets/images/company_mark.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'نظام الشحن',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
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
