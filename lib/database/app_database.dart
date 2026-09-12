
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/roles_table.dart';
import 'tables/permissions_table.dart';
import 'tables/role_permissions_table.dart';
import 'tables/users_table.dart';

import 'daos/permissions_dao.dart';
import 'daos/roles_dao.dart';
import 'daos/users_dao.dart';
import 'daos/role_permissions_dao.dart';

import 'tables/categories_table.dart';
import 'daos/categories_dao.dart';

import 'tables/products_table.dart';
import 'daos/products_dao.dart';

import 'tables/sales_table.dart';
import 'tables/sale_items_table.dart';
import 'daos/sales_dao.dart';
import 'daos/sale_items_dao.dart';

import 'tables/invoice_settings_table.dart';

import 'tables/customers_table.dart';
import 'tables/customer_transactions_table.dart';
import 'daos/customers_dao.dart';
import 'daos/customer_transactions_dao.dart';

import 'tables/stock_movements_table.dart';
import 'daos/stock_movements_dao.dart';

import 'daos/suppliers_dao.dart';
import 'daos/supplier_transactions_dao.dart';
import 'daos/purchases_dao.dart';
import 'daos/purchase_items_dao.dart';
import 'daos/expense_categories_dao.dart';
import 'daos/expenses_dao.dart';

import 'tables/suppliers_table.dart';
import 'tables/supplier_transactions_table.dart';
import 'tables/purchases_table.dart';
import 'tables/purchase_items_table.dart';
import 'tables/expense_categories_table.dart';
import 'tables/expenses_table.dart';
import 'tables/returns_table.dart';
import 'tables/return_items_table.dart';
import 'daos/returns_dao.dart';
import 'daos/return_items_dao.dart';
import 'tables/accounts_table.dart';
import 'tables/journal_entries_table.dart';
import 'tables/journal_lines_table.dart';
import 'daos/accounts_dao.dart';
import 'daos/journal_entries_dao.dart';
import 'daos/journal_lines_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // ============================================================
    // المستخدمون والصلاحيات
    // ============================================================

    Roles,
    Permissions,
    RolePermissions,
    Users,

    // ============================================================
    // المخزون والمنتجات
    // ============================================================

    Categories,
    Products,
    StockMovements,

    // ============================================================
    // المبيعات
    // ============================================================

    Sales,
    SaleItems,

    // ============================================================
    // إعدادات الفاتورة
    // ============================================================

    InvoiceSettings,

    // ============================================================
    // العملاء
    // ============================================================

    Customers,
    CustomerTransactions,

    // ============================================================
    // الموردون والمشتريات
    // ============================================================

    Suppliers,
    SupplierTransactions,
    Purchases,
    PurchaseItems,

    // ============================================================
    // المصروفات
    // ============================================================

    ExpenseCategories,
    Expenses,
    Returns,
    ReturnItems,
    Accounts,
    JournalEntries,
    JournalLines,
  ],
  daos: [
    // ============================================================
    // المستخدمون والصلاحيات
    // ============================================================

    RolesDao,
    PermissionsDao,
    UsersDao,
    RolePermissionsDao,

    // ============================================================
    // المنتجات والمخزون
    // ============================================================

    CategoriesDao,
    ProductsDao,
    StockMovementsDao,

    // ============================================================
    // الموردون والمشتريات
    // ============================================================

    SuppliersDao,
    SupplierTransactionsDao,
    PurchasesDao,
    PurchaseItemsDao,

    // ============================================================
    // المصروفات
    // ============================================================

    ExpenseCategoriesDao,
    ExpensesDao,
    ReturnsDao,
    ReturnItemsDao,
    AccountsDao,
    JournalEntriesDao,
    JournalLinesDao,

    // ============================================================
    // العملاء
    // ============================================================

    CustomersDao,
    CustomerTransactionsDao,

    // ============================================================
    // المبيعات
    // ============================================================

    SalesDao,
    SaleItemsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // ============================================================
  // إصدار قاعدة البيانات
  // ============================================================

  @override
  int get schemaVersion => 11;

  // ============================================================
  // Migration
  // ============================================================

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // ==========================================================
      // إنشاء قاعدة البيانات لأول مرة
      // ==========================================================

      onCreate: (Migrator m) async {
        await m.createAll();
        await _createInvoiceSequence();
        await _createPerformanceIndexes();
        await _createEmployeeTables();
      },

      // ==========================================================
      // ترقية قاعدة البيانات
      // ==========================================================

      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = FULL');
        await customStatement('PRAGMA busy_timeout = 5000');
      },

      onUpgrade: (Migrator m, int from, int to) async {
        // ========================================================
        // الإصدار 1 -> الإصدار 2
        // ========================================================

        if (from < 2) {
          // ------------------------------------------------------
          // إنشاء جدول العملاء
          // ------------------------------------------------------

          await m.createTable(customers);

          // ------------------------------------------------------
          // إنشاء جدول حركات العملاء
          // ------------------------------------------------------

          await m.createTable(customerTransactions);

          // ------------------------------------------------------
          // إضافة customerId إلى جدول المبيعات
          // ------------------------------------------------------

          await m.addColumn(
            sales,
            sales.customerId,
          );
        }

        // ========================================================
        // الإصدار 2 -> الإصدار 3
        // إضافة تاريخ انتهاء الصلاحية للمنتجات
        // ========================================================
        if (from < 3) {
          await m.addColumn(
            products,
            products.expiryDate,
          );
        }

        // ========================================================
        // الإصدار 3 -> الإصدار 4
        // الموردون والمشتريات والمصروفات
        // ========================================================
        if (from < 4) {
          await m.createTable(suppliers);
          await m.createTable(supplierTransactions);
          await m.createTable(purchases);
          await m.createTable(purchaseItems);
          await m.createTable(expenseCategories);
          await m.createTable(expenses);
        }

        // ========================================================
        // الإصدار 4 -> الإصدار 5
        // حفظ تكلفة الشراء التاريخية داخل بنود البيع
        // ========================================================
        if (from < 5) {
          await m.addColumn(
            saleItems,
            saleItems.purchasePriceAtSale,
          );
        }

        if (from < 6) {
          await m.createTable(returns);
          await m.createTable(returnItems);
        }

        if (from < 7) {
          await m.createTable(accounts);
          await m.createTable(journalEntries);
          await m.createTable(journalLines);
        }

        // ========================================================
        // الإصدار 7 -> الإصدار 8
        // إضافة السقف الائتماني للعملاء
        // ========================================================
        if (from < 8) {
          await m.addColumn(
            customers,
            customers.creditLimit,
          );
        }

        if (from < 9) {
          await _createPerformanceIndexes();
        }
        if (from < 10) {
          await _createEmployeeTables();
        }

        if (from < 11) {
          await _createInvoiceSequence();
          await _createPerformanceIndexes();
        }
      },
    );
  }

  Future<void> _createInvoiceSequence() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS invoice_sequence '
      '(id INTEGER PRIMARY KEY CHECK (id = 1), '
      'next_number INTEGER NOT NULL)',
    );

    final existing = await customSelect(
      'SELECT next_number FROM invoice_sequence WHERE id = 1',
    ).getSingleOrNull();

    if (existing == null) {
      final maxRow = await customSelect(
        "SELECT MAX(CASE WHEN invoice_number <> '' "
        "AND invoice_number NOT GLOB '*[^0-9]*' "
        "THEN CAST(invoice_number AS INTEGER) ELSE 0 END) AS max_number "
        "FROM (SELECT invoice_number FROM sales "
        "UNION ALL SELECT invoice_number FROM purchases)",
      ).getSingle();

      final maxNumber = (maxRow.data['max_number'] as num?)?.toInt() ?? 0;
      await customStatement(
        'INSERT INTO invoice_sequence (id, next_number) VALUES (1, ?)',
        [maxNumber + 1],
      );
    }
  }

  Future<String> nextInvoiceNumber() async {
    await customStatement(
      'INSERT OR IGNORE INTO invoice_sequence (id, next_number) VALUES (1, 1)',
    );
    await customStatement(
      'UPDATE invoice_sequence SET next_number = next_number + 1 WHERE id = 1',
    );
    final row = await customSelect(
      'SELECT next_number - 1 AS invoice_number '
      'FROM invoice_sequence WHERE id = 1',
    ).getSingle();
    return row.read<int>('invoice_number').toString();
  }

  Future<void> _createEmployeeTables() async {
    await customStatement("CREATE TABLE IF NOT EXISTS employees (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, job_title TEXT NOT NULL DEFAULT '', salary REAL NOT NULL DEFAULT 0, hire_date TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, notes TEXT, created_at TEXT NOT NULL)");
    await customStatement("CREATE TABLE IF NOT EXISTS employee_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, transaction_date TEXT NOT NULL, description TEXT, notes TEXT, created_at TEXT NOT NULL)");
    await customStatement('CREATE INDEX IF NOT EXISTS idx_employees_active ON employees(is_active)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_employee_transactions_employee ON employee_transactions(employee_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_employee_transactions_date ON employee_transactions(transaction_date)');
  }

  Future<void> _createPerformanceIndexes() async {
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date)',
      'CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_purchases_date ON purchases(purchase_date)',
      'CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON purchases(supplier_id)',
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items(purchase_id)',
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_product ON purchase_items(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_customer_transactions_customer ON customer_transactions(customer_id)',
      'CREATE INDEX IF NOT EXISTS idx_supplier_transactions_supplier ON supplier_transactions(supplier_id)',
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON stock_movements(reference_id)',
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(entry_date)',
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_source ON journal_entries(source_type, source_id)',
      'CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON journal_lines(entry_id)',
      'CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(account_id)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date)',
      'CREATE INDEX IF NOT EXISTS idx_returns_date ON returns(return_date)',
      'CREATE INDEX IF NOT EXISTS idx_return_items_return ON return_items(return_id)',
      'CREATE INDEX IF NOT EXISTS idx_return_items_product ON return_items(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
      'CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name)',
      'CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)',
      'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role_id)',
      'CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name)',
      'CREATE INDEX IF NOT EXISTS idx_permissions_code ON permissions(code)',
      'CREATE INDEX IF NOT EXISTS idx_permissions_name ON permissions(name)',
      'CREATE INDEX IF NOT EXISTS idx_role_permissions_permission ON role_permissions(permission_id)',
      'CREATE INDEX IF NOT EXISTS idx_role_permissions_role_permission ON role_permissions(role_id, permission_id)',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_barcode ON sale_items(barcode)',
      'CREATE INDEX IF NOT EXISTS idx_purchase_items_barcode ON purchase_items(barcode)',
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)',
      'CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)',
      'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)',
      'CREATE INDEX IF NOT EXISTS idx_suppliers_phone ON suppliers(phone)',
      'CREATE INDEX IF NOT EXISTS idx_supplier_transactions_date ON supplier_transactions(date)',
      'CREATE INDEX IF NOT EXISTS idx_customer_transactions_sale ON customer_transactions(sale_id)',
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_returns_number ON returns(return_number)',
      'CREATE INDEX IF NOT EXISTS idx_returns_sale ON returns(sale_id)',
      'CREATE INDEX IF NOT EXISTS idx_returns_purchase ON returns(purchase_id)',
      'CREATE INDEX IF NOT EXISTS idx_return_items_barcode ON return_items(barcode)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_expense_categories_name ON expense_categories(name)',
      'CREATE INDEX IF NOT EXISTS idx_accounts_code ON accounts(code)',
      'CREATE INDEX IF NOT EXISTS idx_accounts_parent ON accounts(parent_id)',
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_number ON journal_entries(entry_number)',
      'CREATE INDEX IF NOT EXISTS idx_journal_lines_account_entry ON journal_lines(account_id, entry_id)',
      'CREATE INDEX IF NOT EXISTS idx_invoice_settings_updated ON invoice_settings(updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON sales(invoice_number)',
      'CREATE INDEX IF NOT EXISTS idx_purchases_invoice_number ON purchases(invoice_number)',
    ];
    for (final sql in indexes) {
      await customStatement(sql);
    }
  }
}

// ==================================================================
// فتح قاعدة البيانات
// ==================================================================

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // --------------------------------------------------------------
    // الحصول على مجلد بيانات التطبيق
    // --------------------------------------------------------------

    final directory =
        await getApplicationSupportDirectory();

    // --------------------------------------------------------------
    // التأكد من وجود المجلد
    // --------------------------------------------------------------

    final dbDirectory =
        Directory(directory.path);

    if (!await dbDirectory.exists()) {
      await dbDirectory.create(
        recursive: true,
      );
    }

    // --------------------------------------------------------------
    // مسار قاعدة البيانات
    // --------------------------------------------------------------

    final file = File(
      p.join(
        directory.path,
        'supermarket_fresh.db',
      ),
    );

    // --------------------------------------------------------------
    // SQLite
    // --------------------------------------------------------------

    return NativeDatabase.createInBackground(
      file,
    );
  });
}
