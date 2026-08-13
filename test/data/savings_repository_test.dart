import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/management_repository.dart';
import 'package:wave/data/savings_repository.dart';

void main() {
  late AppDatabase database;
  late SavingsRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = SavingsRepository(database);
    await seedDatabase(database);
  });

  tearDown(() => database.close());

  test('goal contributions do not affect balances or ledger totals', () async {
    final goalId = await repository.createGoal(
      name: 'Emergency fund',
      targetMinor: 500000,
      linkedAccountId: 'account-bank',
    );
    await repository.addContribution(
      goalId: goalId,
      amountMinor: 75000,
      occurredAt: DateTime(2026, 8, 13),
    );

    final totals = await database.totalsFor(
      ExpensePeriod.month(DateTime(2026, 8)),
    );
    final balances = await database.accountBalances();
    expect(totals.incomeMinor, 0);
    expect(totals.expenseMinor, 0);
    expect(balances.fold<int>(0, (sum, item) => sum + item.balanceMinor), 0);
  });

  test('reversing a contribution removes it from goal progress', () async {
    final goalId = await repository.createGoal(
      name: 'Laptop',
      targetMinor: 100000,
    );
    final contributionId = await repository.addContribution(
      goalId: goalId,
      amountMinor: 25000,
      occurredAt: DateTime(2026, 8, 13),
    );
    var progress = (await repository.watchGoals().first).single;
    expect(progress.savedMinor, 25000);

    await repository.reverseContribution(contributionId);
    progress = (await repository.watchGoals().first).single;
    expect(progress.savedMinor, 0);
    expect(
      (await database.select(database.savingsContributions).getSingle())
          .reversedAt,
      isNotNull,
    );
  });

  test('completed goals reject new contributions until reopened', () async {
    final goalId = await repository.createGoal(
      name: 'Trip',
      targetMinor: 100000,
    );
    await repository.setStatus(goalId, SavingsGoalStatus.completed);

    expect(
      () => repository.addContribution(
        goalId: goalId,
        amountMinor: 1000,
        occurredAt: DateTime(2026, 8, 13),
      ),
      throwsStateError,
    );
  });

  test('goal rejects an archived linked account', () async {
    await ManagementRepository(database).archiveAccount('account-cash');
    expect(
      () => repository.createGoal(
        name: 'Invalid',
        targetMinor: 10000,
        linkedAccountId: 'account-cash',
      ),
      throwsArgumentError,
    );
  });
}
