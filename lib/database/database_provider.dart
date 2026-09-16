
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// المصدر الوحيد لقاعدة البيانات داخل التطبيق.
///
/// يتم إنشاء AppDatabase مرة واحدة فقط،
/// ثم يتم إغلاقها تلقائيًا عند التخلص من Provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(() {
    database.close();
  });

  return database;
});
