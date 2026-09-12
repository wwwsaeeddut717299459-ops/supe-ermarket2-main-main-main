import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
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

/// قاعدة البيانات الرئيسية للتطبيق.
///
/// يتم إنشاء Instance واحدة من AppDatabase
/// لكل ProviderContainer.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(() {
    database.close();
  });

  return database;
});

// ============================================================
// DAOs
// ============================================================
// ============================================================
// CUSTOMERS DAO
// ============================================================

final customersDaoProvider = Provider<CustomersDao>((ref) {
  final database = ref.watch(databaseProvider);

  return CustomersDao(database);
});

// ============================================================
// CUSTOMER TRANSACTIONS DAO
// ============================================================

final customerTransactionsDaoProvider = Provider<CustomerTransactionsDao>((
  ref,
) {
  final database = ref.watch(databaseProvider);

  return CustomerTransactionsDao(database);
});

// ============================================================
// STOCK MOVEMENTS DAO
// ============================================================

final stockMovementsDaoProvider = Provider<StockMovementsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return StockMovementsDao(database);
});
final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  final database = ref.watch(databaseProvider);

  return CategoriesDao(database);
});

final productsDaoProvider = Provider<ProductsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return ProductsDao(database);
});

final rolesDaoProvider = Provider<RolesDao>((ref) {
  final database = ref.watch(databaseProvider);

  return RolesDao(database);
});

final invoiceSettingsDaoProvider = Provider<InvoiceSettingsDao>((ref) {
  return InvoiceSettingsDao(ref.watch(databaseProvider));
});

final invoiceSettingsRepositoryProvider = Provider<InvoiceSettingsRepository>((
  ref,
) {
  return InvoiceSettingsRepository(ref.watch(invoiceSettingsDaoProvider));
});
final permissionsDaoProvider = Provider<PermissionsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return PermissionsDao(database);
});

final rolePermissionsDaoProvider = Provider<RolePermissionsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return RolePermissionsDao(database);
});

final usersDaoProvider = Provider<UsersDao>((ref) {
  final database = ref.watch(databaseProvider);

  return UsersDao(database);
});

final salesDaoProvider = Provider<SalesDao>((ref) {
  final database = ref.watch(databaseProvider);

  return SalesDao(database);
});

final saleItemsDaoProvider = Provider<SaleItemsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return SaleItemsDao(database);
});

final suppliersDaoProvider = Provider<SuppliersDao>((ref) {
  return SuppliersDao(ref.watch(databaseProvider));
});

final supplierTransactionsDaoProvider = Provider<SupplierTransactionsDao>((
  ref,
) {
  return SupplierTransactionsDao(ref.watch(databaseProvider));
});

final purchasesDaoProvider = Provider<PurchasesDao>((ref) {
  return PurchasesDao(ref.watch(databaseProvider));
});

final purchaseItemsDaoProvider = Provider<PurchaseItemsDao>((ref) {
  return PurchaseItemsDao(ref.watch(databaseProvider));
});

final expenseCategoriesDaoProvider = Provider<ExpenseCategoriesDao>((ref) {
  return ExpenseCategoriesDao(ref.watch(databaseProvider));
});

final expensesDaoProvider = Provider<ExpensesDao>((ref) {
  return ExpensesDao(ref.watch(databaseProvider));
});

final returnsDaoProvider = Provider<ReturnsDao>((ref) {
  return ReturnsDao(ref.watch(databaseProvider));
});

final returnItemsDaoProvider = Provider<ReturnItemsDao>((ref) {
  return ReturnItemsDao(ref.watch(databaseProvider));
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
  final database = ref.watch(databaseProvider);
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
  final database = ref.watch(databaseProvider);

  return SaleService(database);
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref.watch(databaseProvider));
});

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ref.watch(databaseProvider));
});

final financeServiceProvider = Provider<FinanceService>((ref) {
  return FinanceService(ref.watch(databaseProvider));
});

final supplierServiceProvider = Provider<SupplierService>((ref) {
  return SupplierService(ref.watch(databaseProvider));
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

final automatedValidationServiceProvider = Provider<AutomatedValidationService>(
  (ref) {
    return AutomatedValidationService(ref.watch(databaseProvider));
  },
);

final returnsServiceProvider = Provider<ReturnsService>((ref) {
  return ReturnsService(ref.watch(databaseProvider));
});

final accountingServiceProvider = Provider<AccountingService>((ref) {
  return AccountingService(ref.watch(databaseProvider));
});

final detailedReportsServiceProvider = Provider<DetailedReportsService>((ref) {
  return DetailedReportsService(ref.watch(databaseProvider));
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.watch(databaseProvider));
});

final businessAnalyticsServiceProvider = Provider<BusinessAnalyticsService>((ref) {
  return BusinessAnalyticsService(ref.watch(databaseProvider));
});

final employeeServiceProvider = Provider<EmployeeService>((ref) => EmployeeService(ref.watch(databaseProvider)));
