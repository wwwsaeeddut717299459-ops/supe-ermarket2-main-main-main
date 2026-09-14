import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AuditEntry {
  final String id;
  final DateTime timestamp;
  final String user;
  final String action;
  final String details;

  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.user,
    required this.action,
    required this.details,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
        user: json['user']?.toString() ?? 'غير معروف',
        action: json['action']?.toString() ?? '',
        details: json['details']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'user': user,
        'action': action,
        'details': details,
      };
}

/// سجل تدقيق محلي للعمليات الحساسة. لا يدخل في الحسابات المالية ولا يغيّرها.
class AuditService {
  static const _fileName = 'audit_log.json';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File(p.join(directory.path, _fileName));
  }

  Future<List<AuditEntry>> getAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> log({
    required String user,
    required String action,
    required String details,
  }) async {
    final file = await _file();
    final entries = await getAll();
    entries.insert(
      0,
      AuditEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        user: user,
        action: action,
        details: details,
      ),
    );
    final trimmed = entries.take(2000).toList();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(trimmed.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }
}
