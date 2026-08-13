import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/schedule_repository.dart';

void main() {
  late AppDatabase database;
  late ScheduleRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ScheduleRepository(database);
    await seedDatabase(database);
  });

  tearDown(() => database.close());

  test('planned activity does not affect actual totals or balances', () async {
    await repository.create(
      type: 'expense',
      amountMinor: 45000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      nextDueAt: DateTime(2026, 9, 1),
    );

    final totals = await database.totalsFor(
      ExpensePeriod.month(DateTime(2026, 9)),
    );
    final balance = (await database.accountBalances())
        .singleWhere((item) => item.account.id == 'account-cash')
        .balanceMinor;
    expect(totals.expenseMinor, 0);
    expect(balance, 0);
  });

  test(
    'posting atomically creates a ledger entry and completes one-time plan',
    () async {
      final id = await repository.create(
        type: 'income',
        amountMinor: 100000,
        accountId: 'account-cash',
        categoryId: 'category-salary',
        nextDueAt: DateTime(2026, 9, 1),
      );
      final ledgerId = await repository.post(
        id,
        postedAt: DateTime(2026, 9, 1, 9),
      );

      final schedule = await database
          .select(database.scheduledTransactions)
          .getSingle();
      final occurrence = await database
          .select(database.scheduledOccurrences)
          .getSingle();
      final ledger = await database
          .select(database.ledgerTransactions)
          .getSingle();
      expect(schedule.status, ScheduleStatus.completed.name);
      expect(occurrence.state, 'posted');
      expect(occurrence.ledgerTransactionId, ledgerId);
      expect(ledger.amountMinor, 100000);
    },
  );

  test(
    'monthly recurrence returns to anchor day after a short month',
    () async {
      final id = await repository.create(
        type: 'expense',
        amountMinor: 1000,
        accountId: 'account-cash',
        categoryId: 'category-food',
        nextDueAt: DateTime(2027, 1, 31),
        recurrence: ScheduleRecurrence.monthly,
      );

      await repository.post(id, postedAt: DateTime(2027, 1, 31));
      var schedule = await database
          .select(database.scheduledTransactions)
          .getSingle();
      expect(schedule.nextDueAt, DateTime(2027, 2, 28));

      await repository.post(id, postedAt: DateTime(2027, 2, 28));
      schedule = await database
          .select(database.scheduledTransactions)
          .getSingle();
      expect(schedule.nextDueAt, DateTime(2027, 3, 31));
    },
  );

  test('skipping records history without creating a ledger entry', () async {
    final id = await repository.create(
      type: 'expense',
      amountMinor: 1000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      nextDueAt: DateTime(2026, 9, 1),
      recurrence: ScheduleRecurrence.weekly,
    );
    await repository.skip(id);

    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    final occurrence = await database
        .select(database.scheduledOccurrences)
        .getSingle();
    expect(occurrence.state, 'skipped');
    final schedule = await database
        .select(database.scheduledTransactions)
        .getSingle();
    expect(schedule.nextDueAt, DateTime(2026, 9, 8));
  });

  test('forecast includes every recurring occurrence in range', () async {
    await repository.create(
      type: 'expense',
      amountMinor: 1000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      nextDueAt: DateTime(2026, 9, 1),
      recurrence: ScheduleRecurrence.weekly,
    );

    final forecast = await repository.forecast(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30),
    );
    expect(forecast.expenseMinor, 5000);
  });

  test('forecast efficiently advances a long-overdue daily schedule', () async {
    await repository.create(
      type: 'income',
      amountMinor: 100,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      nextDueAt: DateTime(2000, 1, 1),
      recurrence: ScheduleRecurrence.daily,
    );

    final forecast = await repository.forecast(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 8),
    );
    expect(forecast.incomeMinor, 700);
  });

  test('rescheduling records the original occurrence state', () async {
    final id = await repository.create(
      type: 'income',
      amountMinor: 1000,
      accountId: 'account-cash',
      categoryId: 'category-salary',
      nextDueAt: DateTime(2026, 9, 1),
    );
    await repository.reschedule(id, DateTime(2026, 9, 3));

    final occurrence = await database
        .select(database.scheduledOccurrences)
        .getSingle();
    final schedule = await database
        .select(database.scheduledTransactions)
        .getSingle();
    expect(occurrence.state, 'rescheduled');
    expect(occurrence.dueAt, DateTime(2026, 9, 1));
    expect(schedule.nextDueAt, DateTime(2026, 9, 3));
  });
}
