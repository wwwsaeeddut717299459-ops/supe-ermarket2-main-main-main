import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'accounting_service.dart';

class SupplierService {
  final AppDatabase db;

  SupplierService(this.db);

  Future<int> create({
    required String name,
    String? phone,
    String? address,
    String? email,
    double openingBalance = 0,
  }) async {
    if (name.trim().isEmpty) throw Exception('اسم المورد مطلوب');
    if (openingBalance < 0) throw Exception('الرصيد الافتتاحي غير صحيح');

    return db.transaction(() async {
      final id = await db.suppliersDao.insertSupplier(
        SuppliersCompanion.insert(
          name: name.trim(),
          phone: Value(phone),
          address: Value(address),
          email: Value(email),
          openingBalance: Value(openingBalance),
          currentBalance: Value(openingBalance),
        ),
      );

      if (openingBalance > 0) {
        await db.supplierTransactionsDao.insertTransaction(
          SupplierTransactionsCompanion.insert(
            supplierId: id,
            type: 'opening_balance',
            amount: Value(openingBalance),
            notes: const Value('رصيد افتتاحي'),
          ),
        );
      }

      await AccountingService(db).rebuildInTransaction();
      return id;
    });
  }

  Future<void> update(
    Supplier supplier, {
    required String name,
    String? phone,
    String? address,
    String? email,
  }) async {
    if (name.trim().isEmpty) throw Exception('اسم المورد مطلوب');

    await db.suppliersDao.updateSupplier(
      supplier.toCompanion(true).copyWith(
            name: Value(name.trim()),
            phone: Value(phone),
            address: Value(address),
            email: Value(email),
            updatedAt: Value(DateTime.now()),
          ),
    );
  }

  Future<void> deactivate(int supplierId) async {
    final supplier = await db.suppliersDao.getById(supplierId);
    if (supplier == null) throw Exception('المورد غير موجود');
    if (supplier.currentBalance.abs() > 0.01) {
      throw Exception('لا يمكن حذف مورد لديه مستحقات قائمة');
    }
    await db.suppliersDao.deactivate(supplierId);
  }

  Future<void> recordPayment({
    required int supplierId,
    required double amount,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception('قيمة الدفعة يجب أن تكون أكبر من صفر');
    }

    await db.transaction(() async {
      final supplier = await db.suppliersDao.getById(supplierId);
      if (supplier == null) throw Exception('المورد غير موجود');
      if (amount > supplier.currentBalance + 0.01) {
        throw Exception('الدفعة أكبر من المستحقات');
      }

      await (db.update(db.suppliers)
            ..where((s) => s.id.equals(supplierId)))
          .write(
        SuppliersCompanion(
          currentBalance: Value(supplier.currentBalance - amount),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.supplierTransactionsDao.insertTransaction(
        SupplierTransactionsCompanion.insert(
          supplierId: supplierId,
          type: 'payment',
          amount: Value(-amount),
          notes: Value(notes),
        ),
      );

      await AccountingService(db).rebuildInTransaction();
    });
  }
}
