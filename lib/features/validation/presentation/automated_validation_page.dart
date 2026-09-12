import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/database_providers.dart';
import '../../../services/automated_validation_service.dart';

class AutomatedValidationPage extends ConsumerStatefulWidget {
  const AutomatedValidationPage({super.key});

  @override
  ConsumerState<AutomatedValidationPage> createState() =>
      _AutomatedValidationPageState();
}

class _AutomatedValidationPageState
    extends ConsumerState<AutomatedValidationPage> {
  Future<ValidationReport>? _report;

  void _run() {
    setState(() {
      _report = ref.read(automatedValidationServiceProvider).run();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التحقق الآلي'),
          actions: [
            IconButton(onPressed: _run, icon: const Icon(Icons.fact_check)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<ValidationReport>(
            future: _report,
            builder: (context, snapshot) {
              if (_report == null) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: _run,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('تشغيل التحقق'),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('فشل التحقق: ${snapshot.error}'));
              }
              final report = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: report.passed
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(
                            report.passed ? Icons.check_circle : Icons.error,
                            color: report.passed ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            report.passed
                                ? 'اجتاز النظام التحقق'
                                : 'توجد مشكلات تحتاج إلى معالجة',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('وقت الفحص: ${report.checkedAt}'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: report.issues.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final issue = report.issues[index];
                        final color = issue.severity == 'error'
                            ? Colors.red
                            : issue.severity == 'warning'
                            ? Colors.orange
                            : Colors.green;
                        final icon = issue.severity == 'error'
                            ? Icons.error
                            : issue.severity == 'warning'
                            ? Icons.warning
                            : Icons.check_circle;
                        return ListTile(
                          leading: Icon(icon, color: color),
                          title: Text(issue.message),
                          subtitle: Text('${issue.code} — ${issue.severity}'),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
