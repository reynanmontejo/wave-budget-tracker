import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/wave_theme.dart';
import '../../data/backup_service.dart';
import '../../data/providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final backup = await ref.read(backupServiceProvider).createJsonBackup();
      ref.invalidate(backupListProvider);
      _showMessage('Backup saved to ${backup.file.path}');
    } on FileSystemException catch (error) {
      _showMessage('Backup failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final export = await ref.read(backupServiceProvider).exportCsv();
      _showMessage('CSV saved to ${export.file.path}');
    } on FileSystemException catch (error) {
      _showMessage('CSV export failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all Wave data?'),
        content: Text(
          'Restore the backup from ${DateFormat.yMMMd().add_jm().format(backup.createdAt)}? Current accounts, transactions, transfers, and budgets will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final summary = await ref
          .read(backupServiceProvider)
          .restore(backup.file);
      _invalidateAppData();
      _showMessage(
        'Restored ${summary.accounts} accounts and ${summary.transactions} transactions.',
      );
    } on FormatException catch (error) {
      _showMessage('Restore rejected: ${error.message}');
    } on FileSystemException catch (error) {
      _showMessage('Restore failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalidateAppData() {
    ref.invalidate(accountsProvider);
    ref.invalidate(allCategoriesProvider);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(incomeCategoriesProvider);
    ref.invalidate(totalsProvider);
    ref.invalidate(accountBalancesProvider);
    ref.invalidate(transactionEntriesProvider);
    ref.invalidate(activityEntriesProvider);
    ref.invalidate(budgetProgressProvider);
    ref.invalidate(homeBudgetProgressProvider);
    ref.invalidate(expenseReportProvider);
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backups = ref.watch(backupListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: WaveColors.primaryContainer,
                    foregroundColor: WaveColors.primaryStrong,
                    child: Icon(Icons.lock_outline_rounded),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Backups stay on this device in Wave’s documents folder. Copy them elsewhere to protect against device loss.',
                      style: TextStyle(color: WaveColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _createBackup,
            icon: const Icon(Icons.backup_rounded),
            label: const Text('Create JSON backup'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export transactions as CSV'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Backup history',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          backups.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Unable to read the backup folder.'),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No backups yet. Create one before making major changes.',
                      ),
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (var index = 0; index < items.length; index++) ...[
                          ListTile(
                            leading: const Icon(
                              Icons.description_outlined,
                              color: WaveColors.primary,
                            ),
                            title: Text(
                              DateFormat.yMMMd().add_jm().format(
                                items[index].createdAt,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${_fileSize(items[index].sizeBytes)} • ${items[index].file.path}',
                            ),
                            trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _restore(items[index]),
                              child: const Text('Restore'),
                            ),
                          ),
                          if (index != items.length - 1)
                            const Divider(height: 1, indent: 56),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _fileSize(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';
}
