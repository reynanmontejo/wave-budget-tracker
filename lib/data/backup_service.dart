import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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
  });
  final int accounts;
  final int transactions;
  final int transfers;
  final int budgets;
}

final class BackupService {
  BackupService(this.database, {DirectoryProvider? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  static const format = 'wave-budget-backup';
  static const schemaVersion = 1;

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
    final payload = <String, dynamic>{
      'format': format,
      'schemaVersion': schemaVersion,
      'exportedAt': now.toUtc().toIso8601String(),
      'data': {
        'accounts': (await database.select(database.accounts).get())
            .map((item) => item.toJson())
            .toList(),
        'categories': (await database.select(database.categories).get())
            .map((item) => item.toJson())
            .toList(),
        'transactions':
            (await database.select(database.ledgerTransactions).get())
                .map((item) => item.toJson())
                .toList(),
        'transfers': (await database.select(database.transfers).get())
            .map((item) => item.toJson())
            .toList(),
        'budgets': (await database.select(database.budgets).get())
            .map((item) => item.toJson())
            .toList(),
      },
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
    final buffer = StringBuffer(
      'id,type,amount_minor,currency,account,category,occurred_at,note\r\n',
    );
    for (final item in transactions) {
      buffer.writeln(
        [
          item.id,
          item.type,
          item.amountMinor,
          'PHP',
          accounts[item.accountId] ?? item.accountId,
          categories[item.categoryId] ?? item.categoryId,
          item.occurredAt.toIso8601String(),
          item.note ?? '',
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
    if (decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported backup version.');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Backup data is missing.');
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
    _validateReferences(accounts, categories, transactions, transfers, budgets);

    await database.transaction(() async {
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
    });
    return RestoreSummary(
      accounts: accounts.length,
      transactions: transactions.length,
      transfers: transfers.length,
      budgets: budgets.length,
    );
  }

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
  ) {
    if (accounts.isEmpty) {
      throw const FormatException(
        'A backup must contain at least one account.',
      );
    }
    final accountIds = accounts.map((item) => item.id).toSet();
    final categoryIds = categories.map((item) => item.id).toSet();
    if (accountIds.length != accounts.length ||
        categoryIds.length != categories.length) {
      throw const FormatException('Backup contains duplicate IDs.');
    }
    for (final item in transactions) {
      if (item.amountMinor <= 0 ||
          !accountIds.contains(item.accountId) ||
          !categoryIds.contains(item.categoryId)) {
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
      if (item.limitMinor <= 0 || !categoryIds.contains(item.categoryId)) {
        throw const FormatException('A budget contains invalid references.');
      }
    }
  }

  static String _csvCell(Object value) {
    final text = value.toString();
    return '"${text.replaceAll('"', '""')}"';
  }
}
