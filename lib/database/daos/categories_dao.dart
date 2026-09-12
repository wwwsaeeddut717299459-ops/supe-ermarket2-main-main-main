import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Future<List<Category>> getAll() {
    return select(categories).get();
  }

  Future<List<Category>> search(String query) {
    final normalized = query.trim();

    if (normalized.isEmpty) {
      return getAll();
    }

    return (select(categories)
          ..where(
            (category) => category.name.like('%$normalized%'),
          )
          ..orderBy([
            (category) => OrderingTerm(
              expression: category.name,
            ),
          ]))
        .get();
  }

  Future<Category?> getById(int id) {
    return (select(categories)
          ..where(
            (category) => category.id.equals(id),
          ))
        .getSingleOrNull();
  }

  Future<int> insertCategory(
    CategoriesCompanion category,
  ) {
    return into(categories).insert(category);
  }

  Future<bool> updateCategory(
    CategoriesCompanion category,
  ) {
    return update(categories).replace(category);
  }

  Future<int> deleteCategory(int id) {
    return (delete(categories)
          ..where(
            (category) => category.id.equals(id),
          ))
        .go();
  }
}