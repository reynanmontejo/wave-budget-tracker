import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/data/backup_service.dart';
import 'package:wave/data/budget_repository.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/ledger_repository.dart';
import 'package:wave/data/schedule_repository.dart';
import 'package:wave/data/savings_repository.dart';

void main() {
  late AppDatabase database;
  late Directory directory;
  late BackupService backups;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    directory = Directory(
      '.tmp/backup-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    backups = BackupService(database, directoryProvider: () async => directory);
    await seedDatabase(database);
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('JSON backup restores the complete ledger', () async {
    final ledger = LedgerRepository(database);
    final budget = BudgetRepository(database);
    await ledger.createEntry(
      type: LedgerEntryType.income,
      amountMinor: 200000,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      occurredAt: DateTime(2026, 8, 10),
    );
    await ledger.createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 45000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 10),
      note: 'Lunch',
    );
    await ledger.createTransfer(
      amountMinor: 50000,
      fromAccountId: 'account-cash',
      toAccountId: 'account-bank',
      occurredAt: DateTime(2026, 8, 10),
    );
    await budget.setMonthlyBudget(
      categoryId: 'category-food',
      month: DateTime(2026, 8),
      limitMinor: 100000,
    );
    await ScheduleRepository(database).create(
      type: 'expense',
      amountMinor: 30000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      nextDueAt: DateTime(2026, 9, 1),
      recurrence: ScheduleRecurrence.monthly,
    );
    await SavingsRepository(database).createGoal(
      name: 'Emergency fund',
      targetMinor: 500000,
      linkedAccountId: 'account-bank',
    );
    final backup = await backups.createJsonBackup();

    await database.delete(database.scheduledOccurrences).go();
    await database.delete(database.scheduledTransactions).go();
    await database.delete(database.savingsContributions).go();
    await database.delete(database.savingsGoals).go();
    await database.delete(database.budgets).go();
    await database.delete(database.transfers).go();
    await database.delete(database.ledgerTransactions).go();
    final summary = await backups.restore(backup.file);

    expect(summary.accounts, 2);
    expect(summary.transactions, 2);
    expect(summary.transfers, 1);
    expect(summary.budgets, 1);
    expect(summary.schedules, 1);
    expect(summary.savingsGoals, 1);
    expect(
      await database.select(database.ledgerTransactions).get(),
      hasLength(2),
    );
  });

  test('invalid backup is rejected before live data changes', () async {
    final invalid = File('${directory.path}/invalid.json');
    await invalid.writeAsString(
      '{"format":"wrong","schemaVersion":1,"data":{}}',
    );
    final before = await database.select(database.accounts).get();

    expect(() => backups.restore(invalid), throwsFormatException);
    expect(
      await database.select(database.accounts).get(),
      hasLength(before.length),
    );
  });

  test('backup rejects a transaction using the wrong category type', () async {
    await LedgerRepository(database).createEntry(
      type: LedgerEntryType.income,
      amountMinor: 10000,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      occurredAt: DateTime(2026, 8, 10),
    );
    final backup = await backups.createJsonBackup();
    final payload =
        jsonDecode(await backup.file.readAsString()) as Map<String, dynamic>;
    final data = payload['data'] as Map<String, dynamic>;
    final transactions = data['transactions'] as List<dynamic>;
    (transactions.single as Map<String, dynamic>)['categoryId'] =
        'category-food';
    await backup.file.writeAsString(jsonEncode(payload));

    expect(() => backups.restore(backup.file), throwsFormatException);
  });

  test(
    'encrypted backup verifies and restores only with its password',
    () async {
      final ledger = LedgerRepository(database);
      await ledger.createEntry(
        type: LedgerEntryType.expense,
        amountMinor: 12500,
        accountId: 'account-cash',
        categoryId: 'category-food',
        occurredAt: DateTime(2026, 8, 14),
        note: 'Private purchase',
      );
      final encrypted = await backups.createJsonBackup(
        password: 'correct horse battery staple',
      );
      final raw = await encrypted.file.readAsString();
      expect(raw, isNot(contains('Private purchase')));

      final verification = await backups.verify(
        encrypted.file,
        password: 'correct horse battery staple',
      );
      expect(verification.encrypted, isTrue);
      expect(verification.transactions, 1);
      await expectLater(
        backups.restore(encrypted.file, password: 'incorrect password'),
        throwsA(isA<FormatException>()),
      );
      expect(
        await database.select(database.ledgerTransactions).get(),
        hasLength(1),
      );
    },
  );

  test('encrypted backup requires a sufficiently long password', () async {
    await expectLater(
      backups.createJsonBackup(password: 'short'),
      throwsA(isA<FormatException>()),
    );
  });

  test('CSV export escapes notes containing commas and quotes', () async {
    await LedgerRepository(database).createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 1000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: DateTime(2026, 8, 10),
      note: 'Lunch, "special"',
    );
    final export = await backups.exportCsv();
    final contents = await export.file.readAsString();
    expect(contents, contains('"Lunch, ""special"""'));
  });

  test('CSV export includes transfers and savings records', () async {
    await LedgerRepository(database).createTransfer(
      amountMinor: 5000,
      fromAccountId: 'account-cash',
      toAccountId: 'account-bank',
      occurredAt: DateTime(2026, 8, 14),
    );
    final savings = SavingsRepository(database);
    final goalId = await savings.createGoal(
      name: 'Emergency fund',
      targetMinor: 100000,
    );
    await savings.addContribution(
      goalId: goalId,
      amountMinor: 10000,
      occurredAt: DateTime(2026, 8, 14),
    );

    final export = await backups.exportCsv();
    final contents = await export.file.readAsString();
    expect(contents, contains('transfer'));
    expect(contents, contains('savings_goal'));
    expect(contents, contains('savings_contribution'));
  });
}
