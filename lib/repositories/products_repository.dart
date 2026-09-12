import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/daos/products_dao.dart';

class ProductsRepository {
  final ProductsDao dao;

  ProductsRepository(this.dao);

  Future<List<Product>> getAll() {
    return dao.getAll();
  }

  Future<List<Product>> search(String query) {
    return dao.search(query);
  }

  Future<Product?> getById(int id) {
    return dao.getById(id);
  }

  Future<Product?> getByBarcode(String barcode) {
    return dao.getByBarcode(barcode);
  }

  Future<List<Product>> getLowStock() {
    return dao.getLowStockProducts();
  }

  Future<List<Product>> getExpiringProducts({
    int days = 30,
  }) {
    return dao.getExpiringProducts(
      days: days,
    );
  }

  Future<List<Product>> getExpiredProducts() {
    return dao.getExpiredProducts();
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<int> create({
    required String barcode,
    required String name,
    int? categoryId,
    required double purchasePrice,
    required double sellingPrice,
    double stockQuantity = 0,
    double minimumStock = 0,
    String unit = 'piece',
    DateTime? expiryDate,
  }) {
    return dao.insertProduct(
      ProductsCompanion.insert(
        barcode: barcode,
        name: name,
        categoryId: Value(categoryId),
        purchasePrice: Value(purchasePrice),
        sellingPrice: Value(sellingPrice),
        stockQuantity: Value(stockQuantity),
        minimumStock: Value(minimumStock),
        unit: Value(unit),
        expiryDate: Value(expiryDate),
      ),
    );
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<bool> update({
    required int id,
    required String barcode,
    required String name,
    int? categoryId,
    required double purchasePrice,
    required double sellingPrice,
    required double stockQuantity,
    required double minimumStock,
    required String unit,
    DateTime? expiryDate,
    bool isActive = true,
  }) {
    return dao.updateProduct(
      ProductsCompanion(
        id: Value(id),
        barcode: Value(barcode),
        name: Value(name),
        categoryId: Value(categoryId),
        purchasePrice: Value(purchasePrice),
        sellingPrice: Value(sellingPrice),
        stockQuantity: Value(stockQuantity),
        minimumStock: Value(minimumStock),
        unit: Value(unit),
        expiryDate: Value(expiryDate),
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<int> delete(int id) {
    return dao.deleteProduct(id);
  }
}