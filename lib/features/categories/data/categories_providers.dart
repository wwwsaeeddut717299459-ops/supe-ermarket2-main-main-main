
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'package:almajed_pro/core/database/daos/categories_dao.dart';
import 'package:almajed_pro/core/database/database_provider.dart';
import 'package:almajed_pro/features/categories/data/repositories/categories_repository.dart';

final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  final database = ref.watch(databaseProvider);

  return CategoriesDao(database);
});

final categoriesRepositoryProvider =
    Provider<CategoriesRepository>((ref) {
  final dao = ref.watch(categoriesDaoProvider);

  return CategoriesRepository(dao);
});
