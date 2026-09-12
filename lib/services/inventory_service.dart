
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'accounting_service.dart';

class InventoryService {
  final AppDatabase db;

  InventoryService(this.db);

  // ============================================================
  // إضافة كمية إلى المخزون
  //
  // تستخدم في:
  // - المشتريات
  // - الرصيد الافتتاحي
  // - مرتجع البيع
  // ============================================================

  Future<void> addStock({
    required int productId,
    required double quantity,
    required String type,
    String? referenceNumber,
    int? referenceId,
    String? notes,
  }) async {
    if (quantity <= 0) {
      throw Exception(
        'الكمية المضافة يجب أن تكون أكبر من صفر',
      );
    }

    await db.transaction(() async {
      final product =
          await db.productsDao.getById(productId);

      if (product == null) {
        throw Exception(
          'المنتج غير موجود',
        );
      }

      if (!product.isActive) {
        throw Exception(
          'المنتج غير نشط',
        );
      }

      final newBalance =
          product.stockQuantity + quantity;

      // تحديث رصيد المنتج
      await db.productsDao.updateProduct(
        ProductsCompanion(
          id: Value(product.id),
          barcode: Value(product.barcode),
          name: Value(product.name),
          categoryId: Value(product.categoryId),
          purchasePrice: Value(product.purchasePrice),
          sellingPrice: Value(product.sellingPrice),
          stockQuantity: Value(newBalance),
          minimumStock: Value(product.minimumStock),
          unit: Value(product.unit),
          isActive: Value(product.isActive),
          createdAt: Value(product.createdAt),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // تسجيل حركة المخزون
      await db.stockMovementsDao.insertMovement(
        StockMovementsCompanion.insert(
          productId: productId,
          type: type,
          quantity: Value(quantity),
          balanceAfter: Value(newBalance),
          referenceNumber:
              Value(referenceNumber),
          referenceId: Value(referenceId),
          notes: Value(notes),
        ),
      );
    });
  }

  // ============================================================
  // خصم كمية من المخزون
  //
  // تستخدم في:
  // - البيع
  // - مرتجع الشراء
  // ============================================================

  Future<void> removeStock({
    required int productId,
    required double quantity,
    required String type,
    String? referenceNumber,
    int? referenceId,
    String? notes,
  }) async {
    if (quantity <= 0) {
      throw Exception(
        'الكمية المخصومة يجب أن تكون أكبر من صفر',
      );
    }

    await db.transaction(() async {
      final product =
          await db.productsDao.getById(productId);

      if (product == null) {
        throw Exception(
          'المنتج غير موجود',
        );
      }

      if (!product.isActive) {
        throw Exception(
          'المنتج غير نشط',
        );
      }

      // منع المخزون السالب
      if (product.stockQuantity < quantity) {
        throw Exception(
          'المخزون غير كافٍ للمنتج: ${product.name}',
        );
      }

      final newBalance =
          product.stockQuantity - quantity;

      // تحديث رصيد المنتج
      await db.productsDao.updateProduct(
        ProductsCompanion(
          id: Value(product.id),
          barcode: Value(product.barcode),
          name: Value(product.name),
          categoryId: Value(product.categoryId),
          purchasePrice: Value(product.purchasePrice),
          sellingPrice: Value(product.sellingPrice),
          stockQuantity: Value(newBalance),
          minimumStock: Value(product.minimumStock),
          unit: Value(product.unit),
          isActive: Value(product.isActive),
          createdAt: Value(product.createdAt),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // تسجيل حركة المخزون
      await db.stockMovementsDao.insertMovement(
        StockMovementsCompanion.insert(
          productId: productId,
          type: type,
          quantity: Value(-quantity),
          balanceAfter: Value(newBalance),
          referenceNumber:
              Value(referenceNumber),
          referenceId: Value(referenceId),
          notes: Value(notes),
        ),
      );
    });
  }

  // ============================================================
  // تسوية / جرد المخزون
  //
  // هذه الطريقة تقارن:
  //
  // المخزون الحالي
  //        ↓
  // الكمية الفعلية في الجرد
  //
  // ثم تسجل الفرق كحركة adjustment.
  // ============================================================

  Future<void> adjustStock({
    required int productId,
    required double actualQuantity,
    String type = 'adjustment',
    String? referenceNumber,
    int? referenceId,
    String? notes,
  }) async {
    if (actualQuantity < 0) {
      throw Exception(
        'كمية الجرد لا يمكن أن تكون سالبة',
      );
    }

    await db.transaction(() async {
      final product =
          await db.productsDao.getById(productId);

      if (product == null) {
        throw Exception(
          'المنتج غير موجود',
        );
      }

      final difference =
          actualQuantity - product.stockQuantity;

      // لا توجد حاجة لتسجيل حركة إذا لم يتغير المخزون
      if (difference == 0) {
        return;
      }

      // تحديث المخزون
      await db.productsDao.updateProduct(
        ProductsCompanion(
          id: Value(product.id),
          barcode: Value(product.barcode),
          name: Value(product.name),
          categoryId: Value(product.categoryId),
          purchasePrice: Value(product.purchasePrice),
          sellingPrice: Value(product.sellingPrice),
          stockQuantity:
              Value(actualQuantity),
          minimumStock: Value(product.minimumStock),
          unit: Value(product.unit),
          isActive: Value(product.isActive),
          createdAt: Value(product.createdAt),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // تسجيل الفرق
      final movementId = await db.stockMovementsDao.insertMovement(
        StockMovementsCompanion.insert(
          productId: productId,
          type: type,
          quantity: Value(difference),
          balanceAfter:
              Value(actualQuantity),
          referenceNumber:
              Value(referenceNumber),
          referenceId:
              Value(referenceId),
          notes: Value(notes),
        ),
      );

      if (movementId > 0) {
        await AccountingService(db).rebuildInTransaction();
      }
    });
  }

  // ============================================================
  // جلب الرصيد الحالي
  // ============================================================

  Future<double> getStock(
    int productId,
  ) async {
    final product =
        await db.productsDao.getById(productId);

    if (product == null) {
      throw Exception(
        'المنتج غير موجود',
      );
    }

    return product.stockQuantity;
  }

  // ============================================================
  // التحقق من توفر كمية
  // ============================================================

  Future<bool> hasEnoughStock({
    required int productId,
    required double quantity,
  }) async {
    if (quantity <= 0) {
      return false;
    }

    final product =
        await db.productsDao.getById(productId);

    if (product == null) {
      return false;
    }

    return product.stockQuantity >= quantity;
  }

  // ============================================================
  // جلب المنتجات التي وصلت للحد الأدنى
  // ============================================================

  Future<List<Product>> getLowStockProducts() {
    return (db.select(db.products)
          ..where(
            (product) =>
                product.isActive.equals(true) &
                product.stockQuantity.isSmallerOrEqual(
                  product.minimumStock,
                ),
          )
          ..orderBy([
            (product) => OrderingTerm(
                  expression:
                      product.stockQuantity,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }
}
