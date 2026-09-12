import 'package:flutter/material.dart';

import '../../accounting/presentation/accounting_page.dart';
import '../../audit/presentation/audit_log_page.dart';
import '../../shifts/presentation/shift_closing_page.dart';
import '../../backup/presentation/backup_restore_page.dart';
import '../../catalog/presentation/catalog_page.dart';
import '../../customers/presentation/customers_page.dart';
import '../../expenses/presentation/expenses_page.dart';
import '../../inventory/pages/inventory_management_page.dart';
import '../../invoices/presentation/invoices_page.dart';
import '../../operations/presentation/operations_page.dart';
import '../../purchases/presentation/purchases_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../returns/presentation/returns_page.dart';
import '../../sales/pages/sales_page.dart';
import '../../settings/invoice_settings_page.dart';
import '../../suppliers/presentation/suppliers_page.dart';
import '../../validation/presentation/automated_validation_page.dart';
import '../../forecast/presentation/profit_forecast_page.dart';
import '../../employees/presentation/employees_page.dart';
import '../../tips/presentation/tips_page.dart';
import 'dashboard_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  late final List<_AppSection> _sections;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _sections = [
      _AppSection(
        title: 'الرئيسية',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: DashboardPage(
          onNavigate: _navigateTo,
        ),
      ),

      _AppSection(
        title: 'نقطة البيع',
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        page: const SalesPage(),
      ),

      _AppSection(
        title: 'المنتجات',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        page: const CatalogPage(),
      ),

      _AppSection(
        title: 'المخزون',
        icon: Icons.warehouse_outlined,
        selectedIcon: Icons.warehouse,
        page: const InventoryManagementPage(),
      ),

      _AppSection(
        title: 'المبيعات',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        page: const InvoicesPage(
          initialType: 'sale',
          title: 'المبيعات والفواتير',
        ),
      ),

      _AppSection(
        title: 'المشتريات',
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart,
        page: const PurchasesPage(),
      ),

      _AppSection(
        title: 'العملاء',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        page: const CustomersPage(),
      ),

      _AppSection(
        title: 'الموردون',
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        page: const SuppliersPage(),
      ),

      _AppSection(title: 'الموظفون', icon: Icons.badge_outlined, selectedIcon: Icons.badge, page: const EmployeesPage()),
      _AppSection(title: 'النصائح', icon: Icons.lightbulb_outline_rounded, selectedIcon: Icons.lightbulb_rounded, page: const TipsPage()),

      _AppSection(
        title: 'المصروفات',
        icon: Icons.money_off_outlined,
        selectedIcon: Icons.money_off,
        page: const ExpensesPage(),
      ),

      _AppSection(
        title: 'الحسابات',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        page: const AccountingPage(),
      ),

      _AppSection(
        title: 'النسخ والاستعادة',
        icon: Icons.backup_outlined,
        selectedIcon: Icons.backup,
        page: const BackupRestorePage(),
      ),

      _AppSection(
        title: 'إغلاق اليوم',
        icon: Icons.lock_clock_outlined,
        selectedIcon: Icons.lock_clock,
        page: const ShiftClosingPage(),
      ),

      _AppSection(
        title: 'سجل التدقيق',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        page: const AuditLogPage(),
      ),

      _AppSection(
        title: 'سجل العمليات',
        icon: Icons.history_outlined,
        selectedIcon: Icons.history_rounded,
        page: const OperationsPage(),
      ),

      _AppSection(
        title: 'التقارير',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart_rounded,
        page: const ReportsPage(),
      ),

      _AppSection(
        title: 'التحقق الآلي',
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        page: const AutomatedValidationPage(),
      ),

      _AppSection(
        title: 'المرتجعات',
        icon: Icons.assignment_return_outlined,
        selectedIcon: Icons.assignment_return,
        page: const ReturnsPage(),
      ),

      _AppSection(
        title: 'الإعدادات',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        page: const InvoiceSettingsPage(),
      ),

      _AppSection(
        title: 'كل الفواتير',
        icon: Icons.receipt_outlined,
        selectedIcon: Icons.receipt,
        page: const InvoicesPage(),
      ),

      _AppSection(
        title: 'تنبؤ الأرباح',
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        page: const ProfitForecastPage(),
      ),
    ];

    // إنشاء الصفحات مرة واحدة فقط.
    //
    // IndexedStack سيحافظ على الصفحات داخل شجرة الـ Widget
    // وبالتالي يحافظ على حالتها أثناء التنقل.
    _pages = _sections.map((section) => section.page).toList();
  }

  void _navigateTo(int index) {
    if (index < 0 || index >= _sections.length) {
      return;
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = _sections[_selectedIndex];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerLowest,
        body: SafeArea(
          child: Row(
            children: [
              _buildNavigationRail(context),

              const VerticalDivider(
                width: 1,
                thickness: 1,
              ),

              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(
                      context,
                      currentSection,
                    ),

                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Navigation Rail
  // ============================================================

  Widget _buildNavigationRail(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: BorderDirectional(
          start: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),

          _buildAppLogo(context),

          const SizedBox(height: 20),

          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                itemCount: _sections.length,
                itemBuilder: (context, index) {
                  final section = _sections[index];

                  return _buildNavigationItem(
                    context,
                    index,
                    section,
                  );
                },
              ),
            ),
          ),

          _buildVersion(context),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ============================================================
  // Application Logo
  // ============================================================

  Widget _buildAppLogo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.storefront_rounded,
        size: 30,
        color: colorScheme.primary,
      ),
    );
  }

  // ============================================================
  // Navigation Item
  // ============================================================

  Widget _buildNavigationItem(
    BuildContext context,
    int index,
    _AppSection section,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: section.title,
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateTo(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isSelected
                          ? section.selectedIcon
                          : section.icon,
                      size: 23,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    section.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Top Bar
  // ============================================================

  Widget _buildTopBar(
    BuildContext context,
    _AppSection section,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            section.selectedIcon,
            color: colorScheme.primary,
            size: 25,
          ),

          const SizedBox(width: 12),

          Text(
            section.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const Spacer(),

          _buildHeaderAction(
            context,
            icon: Icons.notifications_none_rounded,
            tooltip: 'الإشعارات',
            onPressed: () {},
          ),

          const SizedBox(width: 8),

          _buildHeaderAction(
            context,
            icon: Icons.help_outline_rounded,
            tooltip: 'المساعدة',
            onPressed: () {},
          ),

          const SizedBox(width: 16),

          _buildUserInfo(context),
        ],
      ),
    );
  }

  // ============================================================
  // Header Action
  // ============================================================

  Widget _buildHeaderAction(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: colorScheme.onSurfaceVariant,
      ),
      style: IconButton.styleFrom(
        backgroundColor:
            colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    );
  }

  // ============================================================
  // User Info
  // ============================================================

  Widget _buildUserInfo(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(width: 8),

          Text(
            'المحاسب',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Version
  // ============================================================

  Widget _buildVersion(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      'v1.0.0',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ================================================================
// App Section Model
// ================================================================

class _AppSection {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const _AppSection({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}
