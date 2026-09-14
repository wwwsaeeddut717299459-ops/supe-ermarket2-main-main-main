import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/database_providers.dart';

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  Future<List<File>>? _backups;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _backups = ref.read(backupServiceProvider).listBackups();

  Future<void> _create() async {
    final destination = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
    );
    if (destination == null || destination.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final file = await ref.read(backupServiceProvider).createBackup(
        destinationDirectory: destination,
      );
      if (!mounted) return;
      setState(() {
        _message = 'تم إنشاء نسخة شاملة من ${file.path}';
        _load();
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'فشل إنشاء النسخة: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inspect(File file) async {
    try {
      final metadata = await ref
          .read(backupServiceProvider)
          .inspectBackup(file.path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تفاصيل النسخة'),
          content: Text(
            'الصيغة: ${metadata['format']}\nعدد الملفات: ${metadata['fileCount'] ?? 1}\nالحالة: ${metadata['valid'] == true ? 'سليمة' : 'غير صالحة'}\nالحجم: ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _message = 'فشل فحص النسخة: $error');
    }
  }

  Future<void> _restore() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية',
        type: FileType.custom,
        allowedExtensions: ['zip', 'db'],
      );
      final path = picked?.files.single.path;
      if (path == null || path.isEmpty || !mounted) return;
      final metadata = await ref
          .read(backupServiceProvider)
          .inspectBackup(path);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد الاستعادة'),
          content: Text(
            'النسخة صالحة وتحتوي على ${metadata['fileCount'] ?? 1} ملف. سيتم إنشاء نسخة أمان تلقائية من الحالة الحالية، ثم إغلاق قاعدة البيانات واستبدال البيانات والملفات. يجب إعادة تشغيل التطبيق بعد الاستعادة. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _busy = true);
      await ref.read(backupServiceProvider).restoreFrom(path);
      if (mounted)
        setState(
          () => _message =
              'تمت الاستعادة بنجاح. أعد تشغيل التطبيق لإعادة فتح البيانات المستعادة.',
        );
    } catch (error) {
      if (mounted) setState(() => _message = 'فشل الاستعادة: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _fileTile(File file) {
    final isArchive = file.path.toLowerCase().endsWith('.zip');
    return ListTile(
      leading: Icon(isArchive ? Icons.folder_zip : Icons.storage),
      title: Text(file.path.split(Platform.pathSeparator).last),
      subtitle: Text(
        '${file.path}\n${isArchive ? 'نسخة شاملة قابلة للتحقق والاستعادة' : 'نسخة قاعدة بيانات قديمة'}',
      ),
      trailing: TextButton(
        onPressed: () => _inspect(file),
        child: const Text('تفاصيل'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('النسخ الاحتياطي والاستعادة الشاملة'),
          actions: [
            IconButton(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.backup),
            ),
            IconButton(
              onPressed: _busy ? null : _restore,
              icon: const Icon(Icons.restore),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'النسخة الشاملة تشمل قاعدة البيانات، دليل الحسابات والقيود، المنتجات والتصنيفات، المبيعات والمشتريات والمرتجعات، العملاء والموردين، المصروفات، إعدادات الفاتورة، إعدادات العملتين وسعر الصرف، وملفات التطبيق المحلية. تُحفظ النسخة بصيغة ZIP مع فهرس SHA-256 للتحقق من سلامتها.',
                  ),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_message!),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'النسخ المحلية',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<File>>(
                  future: _backups,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return Center(
                        child: Text('تعذر تحميل النسخ: ${snapshot.error}'),
                      );
                    final files = snapshot.data ?? [];
                    if (files.isEmpty)
                      return const Center(
                        child: Text('لا توجد نسخ احتياطية بعد'),
                      );
                    return ListView.separated(
                      itemCount: files.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) => _fileTile(files[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
