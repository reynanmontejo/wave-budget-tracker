import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

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
  DateTime? _lastSuccessfulBackup;
  DateTime? _lastVerifiedBackup;
  DateTime? _lastSuccessfulRestore;
  bool _weeklyBackupReminder = false;

  @override
  void initState() {
    super.initState();
    _loadBackupStatus();
  }

  Future<void> _loadBackupStatus() async {
    final database = ref.read(databaseProvider);
    final values = await Future.wait([
      database.preference('last_successful_backup_at'),
      database.preference('last_verified_backup_at'),
      database.preference('last_successful_restore_at'),
      database.preference('weekly_backup_reminder'),
    ]);
    if (!mounted) return;
    setState(() {
      _lastSuccessfulBackup = DateTime.tryParse(values[0] ?? '');
      _lastVerifiedBackup = DateTime.tryParse(values[1] ?? '');
      _lastSuccessfulRestore = DateTime.tryParse(values[2] ?? '');
      _weeklyBackupReminder = values[3] == 'true';
    });
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final backup = await ref.read(backupServiceProvider).createJsonBackup();
      await _recordSuccessfulBackup();
      ref.invalidate(backupListProvider);
      _showMessage('Backup saved to ${backup.file.path}');
    } on FileSystemException catch (error) {
      _showMessage('Backup failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askBackupPassword({required bool confirm}) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirm ? 'Encrypt backup' : 'Backup password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: password,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (confirm)
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (confirm && password.text != confirmation.text) return;
              Navigator.pop(dialogContext, password.text);
            },
            child: Text(confirm ? 'Create encrypted backup' : 'Continue'),
          ),
        ],
      ),
    );
    password.dispose();
    confirmation.dispose();
    return result;
  }

  Future<void> _createEncryptedBackup() async {
    final password = await _askBackupPassword(confirm: true);
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final backup = await ref
          .read(backupServiceProvider)
          .createJsonBackup(password: password);
      await _recordSuccessfulBackup();
      ref.invalidate(backupListProvider);
      _showMessage('Encrypted backup saved to ${backup.file.path}');
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Encrypted backup failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordSuccessfulBackup() async {
    final completedAt = DateTime.now();
    await ref
        .read(databaseProvider)
        .setPreference(
          'last_successful_backup_at',
          completedAt.toUtc().toIso8601String(),
        );
    if (mounted) setState(() => _lastSuccessfulBackup = completedAt);
  }

  Future<void> _setBackupReminder(bool enabled) async {
    try {
      final scheduled = await ref
          .read(scheduleRepositoryProvider)
          .scheduleBackupReminder(enabled);
      if (!scheduled) {
        _showMessage('Notification permission was not granted.');
        return;
      }
      await ref
          .read(databaseProvider)
          .setPreference('weekly_backup_reminder', enabled.toString());
      if (mounted) setState(() => _weeklyBackupReminder = enabled);
    } catch (error) {
      _showMessage('Unable to update backup reminder: $error');
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final export = await ref.read(backupServiceProvider).exportCsv();
      await _shareFile(export.file, text: 'Wave transaction export');
    } on FileSystemException catch (error) {
      _showMessage('CSV export failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final file = File(path);
      final stat = await file.stat();
      await _restore(
        BackupInfo(file: file, createdAt: stat.modified, sizeBytes: stat.size),
      );
    } catch (error) {
      _showMessage('Unable to open that backup file: $error');
    }
  }

  Future<void> _shareFile(File file, {String? text}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: text),
      );
    } catch (error) {
      _showMessage('Unable to share this file: $error');
    }
  }

  Future<void> _restore(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all Wave data?'),
        content: Text(
          'Restore the backup from ${DateFormat.yMMMd().add_jm().format(backup.createdAt)}? Current accounts, transactions, transfers, budgets, planned activity, and savings goals will be replaced.',
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
    String? password;
    try {
      if (await ref.read(backupServiceProvider).isEncrypted(backup.file)) {
        password = await _askBackupPassword(confirm: false);
        if (password == null) return;
      }
    } catch (error) {
      _showMessage('Unable to inspect this backup: $error');
      return;
    }
    setState(() => _busy = true);
    final schedules = ref.read(scheduleRepositoryProvider);
    try {
      await schedules.cancelAllNotifications();
      final summary = await ref
          .read(backupServiceProvider)
          .restore(backup.file, password: password);
      _invalidateAppData();
      final restoredAt = DateTime.now();
      await ref
          .read(databaseProvider)
          .setPreference(
            'last_successful_restore_at',
            restoredAt.toUtc().toIso8601String(),
          );
      if (mounted) setState(() => _lastSuccessfulRestore = restoredAt);
      _showMessage(
        'Restored ${summary.accounts} accounts and ${summary.transactions} transactions.',
      );
    } on FormatException catch (error) {
      _showMessage('Restore rejected: ${error.message}');
    } on FileSystemException catch (error) {
      _showMessage('Restore failed: ${error.message}');
    } finally {
      try {
        await schedules.syncAllNotifications();
        if (_weeklyBackupReminder) {
          await schedules.scheduleBackupReminder(true);
        }
      } catch (error) {
        _showMessage('Unable to refresh reminders: $error');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _verify(BackupInfo backup) async {
    String? password;
    try {
      final service = ref.read(backupServiceProvider);
      if (await service.isEncrypted(backup.file)) {
        password = await _askBackupPassword(confirm: false);
        if (password == null) return;
      }
      setState(() => _busy = true);
      final result = await service.verify(backup.file, password: password);
      final verifiedAt = DateTime.now();
      await ref
          .read(databaseProvider)
          .setPreference(
            'last_verified_backup_at',
            verifiedAt.toUtc().toIso8601String(),
          );
      if (mounted) setState(() => _lastVerifiedBackup = verifiedAt);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Backup verified'),
          content: Text(
            '${result.encrypted ? 'Encrypted' : 'Unencrypted'} Wave backup\n'
            'Schema ${result.schemaVersion}\n\n'
            '${result.accounts} accounts\n'
            '${result.transactions} transactions\n'
            '${result.transfers} transfers\n'
            '${result.budgets} budgets\n'
            '${result.schedules} planned items\n'
            '${result.savingsGoals} savings goals\n'
            '${result.savingsContributions} contributions',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on FormatException catch (error) {
      _showMessage('Verification failed: ${error.message}');
    } catch (error) {
      _showMessage('Verification failed: $error');
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
    ref.invalidate(scheduledTransactionsProvider);
    ref.invalidate(scheduleForecastProvider);
    ref.invalidate(cashFlowInsightProvider);
    ref.invalidate(savingsGoalsProvider);
    ref.invalidate(dashboardMetricsProvider);
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
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _createEncryptedBackup,
            icon: const Icon(Icons.enhanced_encryption_outlined),
            label: const Text('Create password-encrypted backup'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _importBackup,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Import backup from a file'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _exportCsv,
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export financial data as CSV'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          if (_lastSuccessfulBackup case final completedAt?) ...[
            const SizedBox(height: 12),
            Text(
              'Last successful backup: ${DateFormat.yMMMd().add_jm().format(completedAt.toLocal())}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: WaveColors.muted),
            ),
          ],
          if (_lastVerifiedBackup case final verifiedAt?)
            Text(
              'Last verified: ${DateFormat.yMMMd().add_jm().format(verifiedAt.toLocal())}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: WaveColors.muted),
            ),
          if (_lastSuccessfulRestore case final restoredAt?)
            Text(
              'Last restored: ${DateFormat.yMMMd().add_jm().format(restoredAt.toLocal())}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: WaveColors.muted),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _weeklyBackupReminder,
            onChanged: _busy ? null : _setBackupReminder,
            title: const Text('Weekly backup reminder'),
            subtitle: const Text(
              'Remind me once a week to save a backup outside this phone.',
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
                            trailing: PopupMenuButton<String>(
                              enabled: !_busy,
                              onSelected: (action) {
                                if (action == 'verify') {
                                  _verify(items[index]);
                                } else if (action == 'share') {
                                  _shareFile(
                                    items[index].file,
                                    text: 'Wave budget backup',
                                  );
                                } else if (action == 'restore') {
                                  _restore(items[index]);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'verify',
                                  child: Text('Verify backup'),
                                ),
                                PopupMenuItem(
                                  value: 'share',
                                  child: Text('Share backup'),
                                ),
                                PopupMenuItem(
                                  value: 'restore',
                                  child: Text('Restore backup'),
                                ),
                              ],
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
