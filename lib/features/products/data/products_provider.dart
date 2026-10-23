import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'package:almajed_pro/core/database/database_provider.dart';
import 'package:almajed_pro/core/database/daos/products_dao.dart';
import 'package:almajed_pro/features/products/data/repositories/products_repository.dart';

final productsDaoProvider = Provider<ProductsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return ProductsDao(database);
});



final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final dao = ref.watch(productsDaoProvider);

  return ProductsRepository(dao);
});