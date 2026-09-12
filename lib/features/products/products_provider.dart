import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../database/database_provider.dart';
import '../../database/daos/products_dao.dart';
import '../../repositories/products_repository.dart';

final productsDaoProvider = Provider<ProductsDao>((ref) {
  final database = ref.watch(databaseProvider);

  return ProductsDao(database);
});



final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final dao = ref.watch(productsDaoProvider);

  return ProductsRepository(dao);
});