
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../categories_providers.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() =>
      _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showCategoryDialog({
    int? id,
    String? currentName,
    String? currentDescription,
  }) async {
    final nameController = TextEditingController(
      text: currentName ?? '',
    );

    final descriptionController = TextEditingController(
      text: currentDescription ?? '',
    );

    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          bool saving = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  id == null
                      ? 'إضافة تصنيف'
                      : 'تعديل التصنيف',
                ),
                content: Form(
                  key: formKey,
                  child: SizedBox(
                    width: 450,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          autofocus: true,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'اسم التصنيف',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'أدخل اسم التصنيف';
                            }

                            if (value.trim().length > 100) {
                              return 'اسم التصنيف طويل جدًا';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          enabled: !saving,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'الوصف',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(
                              dialogContext,
                              false,
                            ),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            setDialogState(() {
                              saving = true;
                            });

                            try {
                              final repository = ref.read(
                                categoriesRepositoryProvider,
                              );

                              final name =
                                  nameController.text.trim();

                              final description =
                                  descriptionController.text
                                          .trim()
                                          .isEmpty
                                      ? null
                                      : descriptionController.text
                                          .trim();

                              if (id == null) {
                                await repository.create(
                                  name: name,
                                  description: description,
                                );
                              } else {
                                await repository.update(
                                  id: id,
                                  name: name,
                                  description: description,
                                );
                              }

                              if (dialogContext.mounted) {
                                Navigator.pop(
                                  dialogContext,
                                  true,
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                saving = false;
                              });

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'حدث خطأ أثناء الحفظ: $e',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      saving ? 'جاري الحفظ...' : 'حفظ',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true) {
        await _refresh();
      }
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف التصنيف'),
          content: const Text(
            'هل أنت متأكد من حذف هذا التصنيف؟',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, true),
              icon: const Icon(Icons.delete),
              label: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await ref
          .read(categoriesRepositoryProvider)
          .delete(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف التصنيف بنجاح'),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حذف التصنيف: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository =
        ref.watch(categoriesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التصنيفات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'بحث عن تصنيف...',
                      prefixIcon:
                          const Icon(Icons.search),
                      suffixIcon:
                          _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();

                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  icon:
                                      const Icon(Icons.clear),
                                ),
                      border:
                          const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _showCategoryDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة تصنيف'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: FutureBuilder(
                future: repository.search(_searchQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 50,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'حدث خطأ أثناء تحميل التصنيفات',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    );
                  }

                  final categories = snapshot.data ?? [];

                  if (categories.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 70,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'لا توجد تصنيفات'
                                : 'لا توجد نتائج للبحث',
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_searchQuery.isEmpty)
                            FilledButton.icon(
                              onPressed: () =>
                                  _showCategoryDialog(),
                              icon: const Icon(Icons.add),
                              label:
                                  const Text('إضافة أول تصنيف'),
                            ),
                        ],
                      ),
                    );
                  }

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(
                              label: Text('الرقم'),
                            ),
                            DataColumn(
                              label: Text('اسم التصنيف'),
                            ),
                            DataColumn(
                              label: Text('الوصف'),
                            ),
                            DataColumn(
                              label: Text('الإجراءات'),
                            ),
                          ],
                          rows: categories.map((category) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    category.id.toString(),
                                  ),
                                ),
                                DataCell(
                                  Text(category.name),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Text(
                                      category.description ??
                                          '-',
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'تعديل',
                                        onPressed: _loading
                                            ? null
                                            : () =>
                                                _showCategoryDialog(
                                                  id: category.id,
                                                  currentName:
                                                      category.name,
                                                  currentDescription:
                                                      category
                                                          .description,
                                                ),
                                        icon: const Icon(
                                          Icons.edit,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'حذف',
                                        onPressed: _loading
                                            ? null
                                            : () =>
                                                _deleteCategory(
                                                  category.id,
                                                ),
                                        icon: const Icon(
                                          Icons.delete,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
