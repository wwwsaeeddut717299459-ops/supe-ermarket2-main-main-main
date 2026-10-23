
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/daos/products_dao.dart';
import '../../database/daos/sale_items_dao.dart';
import '../../database/daos/sales_dao.dart';
import '../../database/database_provider.dart';
import '../../repositories/sales_repository.dart';


// ============================================================
// SALES DAO
// ============================================================

final salesDaoProvider = Provider<SalesDao>((ref) {
  final database = ref.watch(databaseProvider);

  return SalesDao(database);
});


// ============================================================
// SALE ITEMS DAO
// ============================================================

final saleItemsDaoProvider =
    Provider<SaleItemsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return SaleItemsDao(database);
});


// ============================================================
// PRODUCTS DAO
// ============================================================

final salesProductsDaoProvider =
    Provider<ProductsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return ProductsDao(database);
});


// ============================================================
// SALES REPOSITORY
// ============================================================

final salesRepositoryProvider =
    Provider<SalesRepository>((ref) {
  final database = ref.watch(databaseProvider);

  final salesDao =
      ref.watch(salesDaoProvider);

  final saleItemsDao =
      ref.watch(saleItemsDaoProvider);

  final productsDao =
      ref.watch(salesProductsDaoProvider);

  return SalesRepository(
    database,
    salesDao,
    saleItemsDao,
    productsDao,
  );
});
