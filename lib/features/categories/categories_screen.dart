import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategory(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load categories.')),
        data: (items) {
          final expense = items
              .where((item) => item.type == 'expense')
              .toList();
          final income = items.where((item) => item.type == 'income').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              _CategoryGroup(title: 'Expenses', items: expense),
              const SizedBox(height: 24),
              _CategoryGroup(title: 'Income', items: income),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddCategory(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var type = 'expense';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {type},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => type = value.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(managementRepositoryProvider)
                      .createCategory(name: name.text, type: type);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } on ArgumentError catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          error.message?.toString() ??
                              'Check the category details.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({required this.title, required this.items});
  final String title;
  final List<Category> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _CategoryTile(category: items[index]),
              if (index != items.length - 1)
                const Divider(height: 1, indent: 64),
            ],
          ],
        ),
      ),
    ],
  );
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});
  final Category category;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: CircleAvatar(
      backgroundColor: Color(category.colorValue).withValues(alpha: 0.12),
      foregroundColor: Color(category.colorValue),
      child: Icon(
        category.type == 'income'
            ? Icons.add_rounded
            : Icons.label_outline_rounded,
      ),
    ),
    title: Text(
      category.name,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: category.isDefault
        ? const Text('Default category')
        : const Text('Custom category'),
    trailing: PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'archive') {
          await ref
              .read(managementRepositoryProvider)
              .archiveCategory(category.id);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'archive', child: Text('Archive')),
      ],
    ),
  );
}
