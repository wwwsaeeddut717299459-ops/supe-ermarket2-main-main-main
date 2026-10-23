
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/daos/categories_dao.dart';

class CategoriesRepository {
  final CategoriesDao dao;

  CategoriesRepository(this.dao);

  // ============================================================
  // GET ALL
  // ============================================================

  Future<List<Category>> getAll() {
    return dao.getAll();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<List<Category>> search(String query) {
    return dao.search(query);
  }

  // ============================================================
  // GET BY ID
  // ============================================================

  Future<Category?> getById(int id) {
    return dao.getById(id);
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<int> create({
    required String name,
    String? description,
  }) {
    final cleanName = name.trim();
    final cleanDescription = description?.trim();

    return dao.insertCategory(
      CategoriesCompanion.insert(
        name: cleanName,
        description: cleanDescription == null ||
                cleanDescription.isEmpty
            ? const Value.absent()
            : Value(cleanDescription),
      ),
    );
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<bool> update({
    required int id,
    required String name,
    String? description,
  }) {
    final cleanName = name.trim();
    final cleanDescription = description?.trim();

    return dao.updateCategory(
      CategoriesCompanion(
        id: Value(id),
        name: Value(cleanName),
        description: Value(
          cleanDescription == null ||
                  cleanDescription.isEmpty
              ? null
              : cleanDescription,
        ),
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<int> delete(int id) {
    return dao.deleteCategory(id);
  }
}
