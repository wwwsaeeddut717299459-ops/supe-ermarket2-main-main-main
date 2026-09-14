import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart' as shared_db;

// استخدام نفس نسخة قاعدة البيانات في جميع أجزاء التطبيق.
export '../database/database_provider.dart' show databaseProvider;
import '../database/daos/customers_dao.dart';
import '../database/daos/customer_transactions_dao.dart';
import '../database/daos/stock_movements_dao.dart';

import '../services/sale_service.dart';
import '../database/daos/categories_dao.dart';
import '../database/daos/products_dao.dart';
import '../database/daos/roles_dao.dart';
import '../database/daos/permissions_dao.dart';
import '../database/daos/role_permissions_dao.dart';
import '../database/daos/users_dao.dart';
import '../database/daos/sales_dao.dart';
import '../database/daos/sale_items_dao.dart';
import '../database/daos/invoice_settings_dao.dart';
import '../database/daos/suppliers_dao.dart';
import '../database/daos/supplier_transactions_dao.dart';
import '../database/daos/purchases_dao.dart';
import '../database/daos/purchase_items_dao.dart';
import '../database/daos/expense_categories_dao.dart';
import '../database/daos/expenses_dao.dart';
import '../database/daos/returns_dao.dart';
import '../database/daos/return_items_dao.dart';
import '../services/purchase_service.dart';
import '../services/finance_service.dart';
import '../services/supplier_service.dart';
import '../services/backup_service.dart';
import '../services/automated_validation_service.dart';
import '../services/returns_service.dart';
import '../services/accounting_service.dart';
import '../services/detailed_reports_service.dart';
import '../services/dashboard_service.dart';
import '../services/business_analytics_service.dart';
import '../services/employee_service.dart';

import '../repositories/invoice_settings_repository.dart';
import '../repositories/categories_repository.dart';
import '../repositories/products_repository.dart';
import '../repositories/sales_repository.dart';
import '../repositories/sale_items_repository.dart';

// ============================================================
// DATABASE
// ============================================================

/// قاعدة البيانات الرئيسية المشتركة للتطبيق.
///
/// هذا الملف يعيد تصدير المزود الموحد من database_provider.dart
/// حتى لا يتم فتح اتصال SQLite ثانٍ، خصوصًا أثناء النسخ والاستعادة.

// ============================================================
// DAOs
// ============================================================
// ============================================================
// CUSTOMERS DAO
// ============================================================

final customersDaoProvider = Provider<CustomersDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return CustomersDao(database);
});

// ============================================================
// CUSTOMER TRANSACTIONS DAO
// ============================================================

final customerTransactionsDaoProvider = Provider<CustomerTransactionsDao>((
  ref,
) {
  final database = ref.watch(shared_db.databaseProvider);

  return CustomerTransactionsDao(database);
});

// ============================================================
// STOCK MOVEMENTS DAO
// ============================================================

final stockMovementsDaoProvider = Provider<StockMovementsDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return StockMovementsDao(database);
});
final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return CategoriesDao(database);
});

final productsDaoProvider = Provider<ProductsDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return ProductsDao(database);
});

final rolesDaoProvider = Provider<RolesDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return RolesDao(database);
});

final invoiceSettingsDaoProvider = Provider<InvoiceSettingsDao>((ref) {
  return InvoiceSettingsDao(ref.watch(shared_db.databaseProvider));
});

final invoiceSettingsRepositoryProvider = Provider<InvoiceSettingsRepository>((
  ref,
) {
  return InvoiceSettingsRepository(ref.watch(invoiceSettingsDaoProvider));
});
final permissionsDaoProvider = Provider<PermissionsDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return PermissionsDao(database);
});

final rolePermissionsDaoProvider = Provider<RolePermissionsDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return RolePermissionsDao(database);
});

final usersDaoProvider = Provider<UsersDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return UsersDao(database);
});

final salesDaoProvider = Provider<SalesDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return SalesDao(database);
});

final saleItemsDaoProvider = Provider<SaleItemsDao>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return SaleItemsDao(database);
});

final suppliersDaoProvider = Provider<SuppliersDao>((ref) {
  return SuppliersDao(ref.watch(shared_db.databaseProvider));
});

final supplierTransactionsDaoProvider = Provider<SupplierTransactionsDao>((
  ref,
) {
  return SupplierTransactionsDao(ref.watch(shared_db.databaseProvider));
});

final purchasesDaoProvider = Provider<PurchasesDao>((ref) {
  return PurchasesDao(ref.watch(shared_db.databaseProvider));
});

final purchaseItemsDaoProvider = Provider<PurchaseItemsDao>((ref) {
  return PurchaseItemsDao(ref.watch(shared_db.databaseProvider));
});

final expenseCategoriesDaoProvider = Provider<ExpenseCategoriesDao>((ref) {
  return ExpenseCategoriesDao(ref.watch(shared_db.databaseProvider));
});

final expensesDaoProvider = Provider<ExpensesDao>((ref) {
  return ExpensesDao(ref.watch(shared_db.databaseProvider));
});

final returnsDaoProvider = Provider<ReturnsDao>((ref) {
  return ReturnsDao(ref.watch(shared_db.databaseProvider));
});

final returnItemsDaoProvider = Provider<ReturnItemsDao>((ref) {
  return ReturnItemsDao(ref.watch(shared_db.databaseProvider));
});

// ============================================================
// REPOSITORIES
// ============================================================

// ============================================================
// REPOSITORIES
// ============================================================

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  final dao = ref.watch(categoriesDaoProvider);

  return CategoriesRepository(dao);
});

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final dao = ref.watch(productsDaoProvider);

  return ProductsRepository(dao);
});

// ============================================================
// SALES REPOSITORY
// ============================================================

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final database = ref.watch(shared_db.databaseProvider);
  final salesDao = ref.watch(salesDaoProvider);
  final saleItemsDao = ref.watch(saleItemsDaoProvider);
  final productsDao = ref.watch(productsDaoProvider);

  return SalesRepository(database, salesDao, saleItemsDao, productsDao);
});

final saleItemsRepositoryProvider = Provider<SaleItemsRepository>((ref) {
  final dao = ref.watch(saleItemsDaoProvider);

  return SaleItemsRepository(dao);
});

// ============================================================
// SALE SERVICE
// ============================================================

final saleServiceProvider = Provider<SaleService>((ref) {
  final database = ref.watch(shared_db.databaseProvider);

  return SaleService(database);
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref.watch(shared_db.databaseProvider));
});

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ref.watch(shared_db.databaseProvider));
});

final financeServiceProvider = Provider<FinanceService>((ref) {
  return FinanceService(ref.watch(shared_db.databaseProvider));
});

final supplierServiceProvider = Provider<SupplierService>((ref) {
  return SupplierService(ref.watch(shared_db.databaseProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(shared_db.databaseProvider));
});

final automatedValidationServiceProvider = Provider<AutomatedValidationService>(
  (ref) {
    return AutomatedValidationService(ref.watch(shared_db.databaseProvider));
  },
);

final returnsServiceProvider = Provider<ReturnsService>((ref) {
  return ReturnsService(ref.watch(shared_db.databaseProvider));
});

final accountingServiceProvider = Provider<AccountingService>((ref) {
  return AccountingService(ref.watch(shared_db.databaseProvider));
});

final detailedReportsServiceProvider = Provider<DetailedReportsService>((ref) {
  return DetailedReportsService(ref.watch(shared_db.databaseProvider));
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.watch(shared_db.databaseProvider));
});

final businessAnalyticsServiceProvider = Provider<BusinessAnalyticsService>((ref) {
  return BusinessAnalyticsService(ref.watch(shared_db.databaseProvider));
});

final employeeServiceProvider = Provider<EmployeeService>((ref) => EmployeeService(ref.watch(shared_db.databaseProvider)));
