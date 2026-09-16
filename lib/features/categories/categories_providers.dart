
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../database/daos/categories_dao.dart';
import '../../database/database_provider.dart';
import '../../repositories/categories_repository.dart';

final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  final database = ref.watch(databaseProvider);

  return CategoriesDao(database);
});

final categoriesRepositoryProvider =
    Provider<CategoriesRepository>((ref) {
  final dao = ref.watch(categoriesDaoProvider);

  return CategoriesRepository(dao);
});
