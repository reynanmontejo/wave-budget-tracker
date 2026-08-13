import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import 'database/app_database.dart';

typedef DirectoryProvider = Future<Directory> Function();

final class BackupInfo {
  const BackupInfo({
    required this.file,
    required this.createdAt,
    required this.sizeBytes,
  });
  final File file;
  final DateTime createdAt;
  final int sizeBytes;
}

final class RestoreSummary {
  const RestoreSummary({
    required this.accounts,
    required this.transactions,
    required this.transfers,
    required this.budgets,
    required this.schedules,
    required this.savingsGoals,
  });
  final int accounts;
  final int transactions;
  final int transfers;
  final int budgets;
  final int schedules;
  final int savingsGoals;
}

final class BackupService {
  BackupService(this.database, {DirectoryProvider? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  static const format = 'wave-budget-backup';
  static const schemaVersion = 4;

  final AppDatabase database;
  final DirectoryProvider _directoryProvider;

  Future<Directory> backupDirectory() async {
    final documents = await _directoryProvider();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}wave_backups',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<BackupInfo> createJsonBackup() async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'accounts': (await database.select(database.accounts).get())
          .map((item) => item.toJson())
          .toList(),
      'categories': (await database.select(database.categories).get())
          .map((item) => item.toJson())
          .toList(),
      'transactions': (await database.select(database.ledgerTransactions).get())
          .map((item) => item.toJson())
          .toList(),
      'transfers': (await database.select(database.transfers).get())
          .map((item) => item.toJson())
          .toList(),
      'budgets': (await database.select(database.budgets).get())
          .map((item) => item.toJson())
          .toList(),
      'scheduledTransactions':
          (await database.select(database.scheduledTransactions).get())
              .map((item) => item.toJson())
              .toList(),
      'scheduledOccurrences':
          (await database.select(database.scheduledOccurrences).get())
              .map((item) => item.toJson())
              .toList(),
      'savingsGoals': (await database.select(database.savingsGoals).get())
          .map((item) => item.toJson())
          .toList(),
      'savingsContributions':
          (await database.select(database.savingsContributions).get())
              .map((item) => item.toJson())
              .toList(),
    };
    final payload = <String, dynamic>{
      'format': format,
      'schemaVersion': schemaVersion,
      'minimumWaveSchemaVersion': 4,
      'exportedAt': now.toUtc().toIso8601String(),
      'checksum': _checksum(data),
      'data': data,
    };
    final directory = await backupDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(now);
    final file = File(
      '${directory.path}${Platform.pathSeparator}wave-backup-$stamp.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    final stat = await file.stat();
    return BackupInfo(
      file: file,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  Future<BackupInfo> exportCsv() async {
    final transactions = await database
        .select(database.ledgerTransactions)
        .get();
    final accounts = {
      for (final item in await database.select(database.accounts).get())
        item.id: item.name,
    };
    final categories = {
      for (final item in await database.select(database.categories).get())
        item.id: item.name,
    };
    final schedules = await database
        .select(database.scheduledTransactions)
        .get();
    final buffer = StringBuffer(
      'record_kind,id,type,amount_minor,currency,account,category,occurred_or_due_at,note,recurrence,status\r\n',
    );
    for (final item in transactions) {
      buffer.writeln(
        [
          'actual',
          item.id,
          item.type,
          item.amountMinor,
          'PHP',
          accounts[item.accountId] ?? item.accountId,
          categories[item.categoryId] ?? item.categoryId,
          item.occurredAt.toIso8601String(),
          item.note ?? '',
          '',
          'posted',
        ].map(_csvCell).join(','),
      );
    }
    for (final item in schedules) {
      buffer.writeln(
        [
          'planned',
          item.id,
          item.type,
          item.amountMinor,
          'PHP',
          accounts[item.accountId] ?? item.accountId,
          categories[item.categoryId] ?? item.categoryId,
          item.nextDueAt.toIso8601String(),
          item.note ?? '',
          item.recurrenceInterval == 1
              ? item.recurrence
              : '${item.recurrence}:${item.recurrenceInterval}',
          item.status,
        ].map(_csvCell).join(','),
      );
    }
    final now = DateTime.now();
    final directory = await backupDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(now);
    final file = File(
      '${directory.path}${Platform.pathSeparator}wave-transactions-$stamp.csv',
    );
    await file.writeAsString(buffer.toString(), flush: true);
    final stat = await file.stat();
    return BackupInfo(
      file: file,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  Future<List<BackupInfo>> listJsonBackups() async {
    final directory = await backupDirectory();
    final result = <BackupInfo>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
        final stat = await entity.stat();
        result.add(
          BackupInfo(
            file: entity,
            createdAt: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<RestoreSummary> restore(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup root must be an object.');
    }
    if (decoded['format'] != format) {
      throw const FormatException('This is not a Wave backup.');
    }
    final backupVersion = decoded['schemaVersion'];
    if (backupVersion != 1 &&
        backupVersion != 2 &&
        backupVersion != 3 &&
        backupVersion != schemaVersion) {
      throw const FormatException('Unsupported backup version.');
    }
    final minimumSchema = decoded['minimumWaveSchemaVersion'];
    if (minimumSchema is int && minimumSchema > database.schemaVersion) {
      throw const FormatException(
        'This backup requires a newer version of Wave.',
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Backup data is missing.');
    }
    if (backupVersion == schemaVersion) {
      final checksum = decoded['checksum'];
      if (checksum is! String || checksum != _checksum(data)) {
        throw const FormatException(
          'Backup checksum does not match. The file may be damaged or modified.',
        );
      }
    }

    final accounts = _decodeList(data, 'accounts', Account.fromJson);
    final categories = _decodeList(data, 'categories', Category.fromJson);
    final transactions = _decodeList(
      data,
      'transactions',
      LedgerTransaction.fromJson,
    );
    final transfers = _decodeList(data, 'transfers', Transfer.fromJson);
    final budgets = _decodeList(data, 'budgets', Budget.fromJson);
    final schedules = backupVersion == 1
        ? <ScheduledTransaction>[]
        : _decodeList(
            data,
            'scheduledTransactions',
            ScheduledTransaction.fromJson,
          );
    final occurrences = backupVersion == 1
        ? <ScheduledOccurrence>[]
        : _decodeList(
            data,
            'scheduledOccurrences',
            ScheduledOccurrence.fromJson,
          );
    final goals = backupVersion == 3 || backupVersion == 4
        ? _decodeList(data, 'savingsGoals', SavingsGoal.fromJson)
        : <SavingsGoal>[];
    final contributions = backupVersion == 3 || backupVersion == 4
        ? _decodeList(
            data,
            'savingsContributions',
            SavingsContribution.fromJson,
          )
        : <SavingsContribution>[];
    _validateReferences(
      accounts,
      categories,
      transactions,
      transfers,
      budgets,
      schedules,
      occurrences,
      goals,
      contributions,
    );

    await database.transaction(() async {
      await database.delete(database.savingsContributions).go();
      await database.delete(database.savingsGoals).go();
      await database.delete(database.scheduledOccurrences).go();
      await database.delete(database.scheduledTransactions).go();
      await database.delete(database.budgets).go();
      await database.delete(database.transfers).go();
      await database.delete(database.ledgerTransactions).go();
      await database.delete(database.categories).go();
      await database.delete(database.accounts).go();
      for (final item in accounts) {
        await database.into(database.accounts).insert(item);
      }
      for (final item in categories) {
        await database.into(database.categories).insert(item);
      }
      for (final item in transactions) {
        await database.into(database.ledgerTransactions).insert(item);
      }
      for (final item in transfers) {
        await database.into(database.transfers).insert(item);
      }
      for (final item in budgets) {
        await database.into(database.budgets).insert(item);
      }
      for (final item in schedules) {
        await database.into(database.scheduledTransactions).insert(item);
      }
      for (final item in occurrences) {
        await database.into(database.scheduledOccurrences).insert(item);
      }
      for (final item in goals) {
        await database.into(database.savingsGoals).insert(item);
      }
      for (final item in contributions) {
        await database.into(database.savingsContributions).insert(item);
      }
    });
    return RestoreSummary(
      accounts: accounts.length,
      transactions: transactions.length,
      transfers: transfers.length,
      budgets: budgets.length,
      schedules: schedules.length,
      savingsGoals: goals.length,
    );
  }

  static String _checksum(Map<String, dynamic> data) =>
      sha256.convert(utf8.encode(jsonEncode(data))).toString();

  List<T> _decodeList<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    final value = data[key];
    if (value is! List) throw FormatException('$key must be a list.');
    return value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$key contains an invalid record.');
      }
      return decode(item);
    }).toList();
  }

  void _validateReferences(
    List<Account> accounts,
    List<Category> categories,
    List<LedgerTransaction> transactions,
    List<Transfer> transfers,
    List<Budget> budgets,
    List<ScheduledTransaction> schedules,
    List<ScheduledOccurrence> occurrences,
    List<SavingsGoal> goals,
    List<SavingsContribution> contributions,
  ) {
    if (accounts.isEmpty) {
      throw const FormatException(
        'A backup must contain at least one account.',
      );
    }
    final accountIds = accounts.map((item) => item.id).toSet();
    final categoryIds = categories.map((item) => item.id).toSet();
    final categoryTypes = {for (final item in categories) item.id: item.type};
    if (accountIds.length != accounts.length ||
        categoryIds.length != categories.length) {
      throw const FormatException('Backup contains duplicate IDs.');
    }
    for (final item in transactions) {
      if (item.amountMinor <= 0 ||
          !accountIds.contains(item.accountId) ||
          !categoryIds.contains(item.categoryId) ||
          (item.type != 'income' && item.type != 'expense') ||
          categoryTypes[item.categoryId] != item.type) {
        throw const FormatException(
          'A transaction contains invalid references.',
        );
      }
    }
    for (final item in transfers) {
      if (item.amountMinor <= 0 ||
          item.fromAccountId == item.toAccountId ||
          !accountIds.contains(item.fromAccountId) ||
          !accountIds.contains(item.toAccountId)) {
        throw const FormatException('A transfer contains invalid references.');
      }
    }
    for (final item in budgets) {
      if (item.limitMinor <= 0 ||
          !categoryIds.contains(item.categoryId) ||
          categoryTypes[item.categoryId] != 'expense') {
        throw const FormatException('A budget contains invalid references.');
      }
    }
    final scheduleIds = schedules.map((item) => item.id).toSet();
    final ledgerIds = transactions.map((item) => item.id).toSet();
    if (scheduleIds.length != schedules.length) {
      throw const FormatException('Backup contains duplicate schedule IDs.');
    }
    for (final item in schedules) {
      if (item.amountMinor <= 0 ||
          !accountIds.contains(item.accountId) ||
          !categoryIds.contains(item.categoryId) ||
          (item.type != 'income' && item.type != 'expense') ||
          categoryTypes[item.categoryId] != item.type) {
        throw const FormatException('A schedule contains invalid references.');
      }
    }
    for (final item in occurrences) {
      if (!scheduleIds.contains(item.scheduleId) ||
          (item.ledgerTransactionId != null &&
              !ledgerIds.contains(item.ledgerTransactionId))) {
        throw const FormatException(
          'A scheduled occurrence contains invalid references.',
        );
      }
    }
    final goalIds = goals.map((item) => item.id).toSet();
    if (goalIds.length != goals.length) {
      throw const FormatException(
        'Backup contains duplicate savings goal IDs.',
      );
    }
    for (final item in goals) {
      if (item.targetMinor <= 0 ||
          (item.linkedAccountId != null &&
              !accountIds.contains(item.linkedAccountId))) {
        throw const FormatException('A savings goal contains invalid data.');
      }
    }
    for (final item in contributions) {
      if (item.amountMinor <= 0 || !goalIds.contains(item.goalId)) {
        throw const FormatException(
          'A savings contribution contains invalid data.',
        );
      }
    }
  }

  static String _csvCell(Object value) {
    final text = value.toString();
    return '"${text.replaceAll('"', '""')}"';
  }
}
