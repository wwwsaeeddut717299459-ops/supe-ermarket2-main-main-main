import 'package:flutter/material.dart';

import '../../../services/audit_service.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _audit = AuditService();
  late Future<List<AuditEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _audit.getAll();
  }

  void _refresh() => setState(() => _future = _audit.getAll());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التدقيق'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<AuditEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) return const Center(child: Text('لا توجد عمليات مسجلة بعد'));
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final entry = entries[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.history)),
                  title: Text(entry.action, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${entry.user} • ${entry.timestamp.toLocal()}\n${entry.details}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
