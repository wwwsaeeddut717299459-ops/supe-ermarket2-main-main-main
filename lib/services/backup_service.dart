import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'currency_service.dart';

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  Future<Directory> supportDirectory() => getApplicationSupportDirectory();

  Future<File> databaseFile() async {
    final directory = await supportDirectory();
    return File(p.join(directory.path, 'supermarket_fresh.db'));
  }

  Future<Directory> backupDirectory() async {
    final support = await supportDirectory();
    final directory = Directory(p.join(support.path, 'backups'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<List<File>> _supportFiles() async {
    final support = await supportDirectory();
    final backupPath = p.normalize((await backupDirectory()).path);
    final files = <File>[];
    await for (final entity in support.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final normalized = p.normalize(entity.path);
      if (normalized == backupPath || p.isWithin(backupPath, normalized))
        continue;
      files.add(entity);
    }
    return files;
  }

  String _relative(String root, String filePath) =>
      p.relative(filePath, from: root).replaceAll(r'\', '/');

  Future<String> _checksum(List<int> bytes) async =>
      sha256.convert(bytes).toString();

  Future<File> createBackup({String? destinationDirectory}) async {
    final support = await supportDirectory();
    final sourceFiles = await _supportFiles();
    if (sourceFiles.isEmpty)
      throw Exception('لا توجد ملفات بيانات لإنشاء نسخة احتياطية');

    final manifestFiles = <Map<String, dynamic>>[];
    final archive = Archive();
    for (final file in sourceFiles) {
      final bytes = await file.readAsBytes();
      final relative = _relative(support.path, file.path);
      manifestFiles.add({
        'path': relative,
        'size': bytes.length,
        'sha256': await _checksum(bytes),
      });
      archive.addFile(ArchiveFile(relative, bytes.length, bytes));
    }

    Map<String, dynamic>? currencySettings;
    try {
      final currencyFile = await CurrencyService().settingsFile();
      if (await currencyFile.exists()) {
        currencySettings = jsonDecode(await currencyFile.readAsString())
            as Map<String, dynamic>;
      }
    } catch (_) {}

    final manifest = {
      'format': 'supermarket-complete-backup',
      'version': 2,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': db.schemaVersion,
      'fileCount': manifestFiles.length,
      'files': manifestFiles,
      'currencySettings': currencySettings,
    };
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    archive.addFile(
      ArchiveFile('backup-manifest.json', manifestBytes.length, manifestBytes),
    );
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty)
      throw Exception('تعذر ضغط النسخة الاحتياطية');

    final directory = destinationDirectory == null
        ? await backupDirectory()
        : Directory(destinationDirectory);
    if (!await directory.exists()) await directory.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final target = File(
      p.join(directory.path, 'supermarket-complete-$stamp.zip'),
    );
    await target.writeAsBytes(encoded, flush: true);
    return target;
  }

  Future<List<File>> listBackups() async {
    final directory = await backupDirectory();
    final files = directory.listSync().whereType<File>().where((file) {
      final extension = p.extension(file.path).toLowerCase();
      return extension == '.zip' || extension == '.db';
    }).toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  Future<Map<String, dynamic>> inspectBackup(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists())
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    if (p.extension(source.path).toLowerCase() == '.db') {
      return {
        'format': 'legacy-database',
        'fileCount': 1,
        'valid': true,
        'size': await source.length(),
      };
    }
    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    final manifestFile = archive.findFile('backup-manifest.json');
    if (manifestFile == null)
      throw Exception('ملف الفهرس backup-manifest.json غير موجود');
    final manifest =
        jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, dynamic>;
    final entries = (manifest['files'] as List<dynamic>? ?? const []);
    for (final entry in entries) {
      final item = entry as Map<String, dynamic>;
      final file = archive.findFile(item['path'] as String);
      if (file == null)
        throw Exception('الملف مفقود من النسخة: ${item['path']}');
      final checksum = await _checksum(file.content as List<int>);
      if (checksum != item['sha256'])
        throw Exception('فشل التحقق من سلامة الملف: ${item['path']}');
    }
    return {...manifest, 'valid': true, 'archiveSize': await source.length()};
  }

  Future<void> restoreFrom(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists())
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    final safety = await createBackup();
    final extension = p.extension(source.path).toLowerCase();
    if (extension == '.db') {
      final target = await databaseFile();
      await db.close();
      await source.copy(target.path);
      return;
    }
    if (extension != '.zip')
      throw Exception('يجب اختيار ملف .zip أو نسخة SQLite قديمة بامتداد .db');

    final support = await supportDirectory();
    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    final manifestFile = archive.findFile('backup-manifest.json');
    if (manifestFile == null) throw Exception('النسخة لا تحتوي على فهرس صالح');
    final manifest =
        jsonDecode(utf8.decode(manifestFile.content as List<int>))
            as Map<String, dynamic>;
    final entries = (manifest['files'] as List<dynamic>? ?? const []);
    for (final entry in entries) {
      final item = entry as Map<String, dynamic>;
      final archiveFile = archive.findFile(item['path'] as String);
      if (archiveFile == null ||
          await _checksum(archiveFile.content as List<int>) != item['sha256'])
        throw Exception('فشل التحقق من سلامة النسخة قبل الاستعادة');
    }

    // The safety snapshot is created before closing the live database.
    if (!await File(safety.path).exists())
      throw Exception('تعذر إنشاء نسخة الأمان قبل الاستعادة');
    await db.close();
    final expectedPaths = entries
        .map((entry) => (entry as Map<String, dynamic>)['path'] as String)
        .toSet();
    for (final file in await _supportFiles()) {
      if (!expectedPaths.contains(_relative(support.path, file.path)))
        await file.delete();
    }
    for (final entry in entries) {
      final item = entry as Map<String, dynamic>;
      final relative = item['path'] as String;
      if (p.isAbsolute(relative) || p.normalize(relative).startsWith('..'))
        throw Exception('مسار غير آمن داخل النسخة');
      final target = File(p.join(support.path, relative));
      await target.parent.create(recursive: true);
      final archiveFile = archive.findFile(relative)!;
      await target.writeAsBytes(archiveFile.content as List<int>, flush: true);
    }
  }
}
