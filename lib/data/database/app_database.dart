import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/period/expense_period.dart';

part 'app_database.g.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get typeName => text().withDefault(const Constant('Cash'))();
  TextColumn get currencyCode => text().withDefault(const Constant('PHP'))();
  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get openingBalanceDate => dateTime()();
  TextColumn get iconKey => text().withDefault(const Constant('wallet'))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF5B8DEF))();
  BoolColumn get includeInNetWorth =>
      boolean().withDefault(const Constant(true))();
  TextColumn get walletProviderName => text().nullable()();
  TextColumn get walletProviderKey => text().nullable()();
  TextColumn get walletIdentifierSuffix =>
      text().withLength(min: 1, max: 4).nullable()();
  DateTimeColumn get walletLastReconciledAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AccountBalanceAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  IntColumn get differenceMinor => integer()();
  IntColumn get observedBalanceMinor => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text()();
  TextColumn get iconKey => text()();
  IntColumn get colorValue => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LedgerTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Transfers extends Table {
  TextColumn get id => text()();
  @ReferenceName('outgoingTransfers')
  TextColumn get fromAccountId => text().references(Accounts, #id)();
  @ReferenceName('incomingTransfers')
  TextColumn get toAccountId => text().references(Accounts, #id)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get periodType => text().withDefault(const Constant('monthly'))();
  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();
  IntColumn get limitMinor => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {categoryId, periodStart, periodEnd},
  ];
}

class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class ScheduledTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get nextDueAt => dateTime()();
  TextColumn get recurrence => text().withDefault(const Constant('none'))();
  IntColumn get recurrenceInterval =>
      integer().withDefault(const Constant(1))();
  IntColumn get recurrenceAnchorDay => integer().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  BoolColumn get autoPost => boolean().withDefault(const Constant(false))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  IntColumn get reminderOffsetMinutes => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get lastPostedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ScheduledOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get scheduleId => text().references(
    ScheduledTransactions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get state => text()();
  TextColumn get ledgerTransactionId =>
      text().nullable().references(LedgerTransactions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {scheduleId, dueAt},
  ];
}

class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get targetMinor => integer()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get linkedAccountId =>
      text().nullable().references(Accounts, #id)();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF269CA3))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SavingsContributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId =>
      text().references(SavingsGoals, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get reversedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

final class PeriodTotals {
  const PeriodTotals({required this.incomeMinor, required this.expenseMinor});

  final int incomeMinor;
  final int expenseMinor;
  int get netMinor => incomeMinor - expenseMinor;
}

final class TransactionEntry {
  const TransactionEntry({
    required this.transaction,
    required this.categoryName,
    required this.accountName,
  });

  final LedgerTransaction transaction;
  final String categoryName;
  final String accountName;
}

final class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.occurredAt,
    required this.title,
    required this.accountName,
    this.destinationName,
    this.categoryId,
    this.accountId,
    this.destinationAccountId,
    this.note,
  });
  final String id;
  final String kind;
  final int amountMinor;
  final DateTime occurredAt;
  final String title;
  final String accountName;
  final String? destinationName;
  final String? categoryId;
  final String? accountId;
  final String? destinationAccountId;
  final String? note;
}

final class AccountBalanceSummary {
  const AccountBalanceSummary({
    required this.account,
    required this.balanceMinor,
  });

  final Account account;
  final int balanceMinor;
}

final class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.categoryName,
    required this.categoryColorValue,
    required this.spentMinor,
  });

  final Budget budget;
  final String categoryName;
  final int categoryColorValue;
  final int spentMinor;
  int get remainingMinor => budget.limitMinor - spentMinor;
  double get fraction =>
      budget.limitMinor == 0 ? 0 : spentMinor / budget.limitMinor;
}

final class CategorySpending {
  const CategorySpending({
    required this.name,
    required this.colorValue,
    required this.amountMinor,
  });
  final String name;
  final int colorValue;
  final int amountMinor;
}

final class SpendingTrendPoint {
  const SpendingTrendPoint({
    required this.label,
    required this.amountMinor,
    required this.sortKey,
  });
  final String label;
  final int amountMinor;
  final int sortKey;
}

final class ExpenseReport {
  const ExpenseReport({
    required this.totals,
    required this.previousTotals,
    required this.categories,
    required this.trend,
    required this.transactionCount,
  });
  final PeriodTotals totals;
  final PeriodTotals previousTotals;
  final List<CategorySpending> categories;
  final List<SpendingTrendPoint> trend;
  final int transactionCount;

  double get expenseChange {
    if (previousTotals.expenseMinor == 0) {
      return totals.expenseMinor == 0 ? 0 : 1;
    }
    return (totals.expenseMinor - previousTotals.expenseMinor) /
        previousTotals.expenseMinor;
  }
}

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    LedgerTransactions,
    Transfers,
    Budgets,
    AppPreferences,
    ScheduledTransactions,
    ScheduledOccurrences,
    SavingsGoals,
    SavingsContributions,
    AccountBalanceAdjustments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'wave'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(appPreferences);
      }
      if (from < 3) {
        await migrator.createTable(scheduledTransactions);
        await migrator.createTable(scheduledOccurrences);
      }
      if (from < 4) {
        await migrator.createTable(savingsGoals);
        await migrator.createTable(savingsContributions);
      }
      if (from < 5) {
        await migrator.addColumn(accounts, accounts.walletProviderName);
        await migrator.addColumn(accounts, accounts.walletProviderKey);
        await migrator.addColumn(accounts, accounts.walletIdentifierSuffix);
        await migrator.addColumn(accounts, accounts.walletLastReconciledAt);
        await migrator.createTable(accountBalanceAdjustments);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<String?> preference(String key) async {
    final row = await (select(
      appPreferences,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setPreference(String key, String value) async {
    await into(appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion.insert(key: key, value: value),
    );
  }

  Stream<List<Account>> watchActiveAccounts() =>
      (select(accounts)..where((row) => row.archivedAt.isNull())).watch();

  Stream<List<Category>> watchActiveCategories(String type) =>
      (select(categories)
            ..where((row) => row.archivedAt.isNull() & row.type.equals(type))
            ..orderBy([(row) => OrderingTerm.asc(row.name)]))
          .watch();

  Stream<List<Category>> watchAllActiveCategories() =>
      (select(categories)
            ..where((row) => row.archivedAt.isNull())
            ..orderBy([
              (row) => OrderingTerm.asc(row.type),
              (row) => OrderingTerm.asc(row.name),
            ]))
          .watch();

  Stream<List<LedgerTransaction>> watchTransactions(ExpensePeriod period) =>
      (select(ledgerTransactions)
            ..where(
              (row) =>
                  row.occurredAt.isBiggerOrEqualValue(period.startInclusive) &
                  row.occurredAt.isSmallerThanValue(period.endExclusive),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
          .watch();

  Stream<List<TransactionEntry>> watchTransactionEntries(ExpensePeriod period) {
    final query =
        select(ledgerTransactions).join([
            innerJoin(
              categories,
              categories.id.equalsExp(ledgerTransactions.categoryId),
            ),
            innerJoin(
              accounts,
              accounts.id.equalsExp(ledgerTransactions.accountId),
            ),
          ])
          ..where(
            ledgerTransactions.occurredAt.isBiggerOrEqualValue(
                  period.startInclusive,
                ) &
                ledgerTransactions.occurredAt.isSmallerThanValue(
                  period.endExclusive,
                ),
          )
          ..orderBy([OrderingTerm.desc(ledgerTransactions.occurredAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TransactionEntry(
              transaction: row.readTable(ledgerTransactions),
              categoryName: row.readTable(categories).name,
              accountName: row.readTable(accounts).name,
            ),
          )
          .toList(),
    );
  }

  Stream<List<ActivityEntry>> watchActivityEntries(ExpensePeriod period) {
    const sql = '''
SELECT lt.id, lt.type AS kind, lt.amount_minor, lt.occurred_at, lt.note,
       c.name AS title, a.name AS account_name, NULL AS destination_name,
       lt.category_id, lt.account_id, NULL AS destination_account_id
FROM ledger_transactions lt
JOIN categories c ON c.id = lt.category_id
JOIN accounts a ON a.id = lt.account_id
WHERE lt.occurred_at >= ? AND lt.occurred_at < ?
UNION ALL
SELECT t.id, 'transfer' AS kind, t.amount_minor, t.occurred_at, t.note,
       'Transfer' AS title, source.name AS account_name,
       destination.name AS destination_name, NULL AS category_id,
       t.from_account_id AS account_id, t.to_account_id AS destination_account_id
FROM transfers t
JOIN accounts source ON source.id = t.from_account_id
JOIN accounts destination ON destination.id = t.to_account_id
WHERE t.occurred_at >= ? AND t.occurred_at < ?
ORDER BY occurred_at DESC
''';
    return customSelect(
      sql,
      variables: [
        Variable.withDateTime(period.startInclusive),
        Variable.withDateTime(period.endExclusive),
        Variable.withDateTime(period.startInclusive),
        Variable.withDateTime(period.endExclusive),
      ],
      readsFrom: {ledgerTransactions, transfers, categories, accounts},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => ActivityEntry(
              id: row.read<String>('id'),
              kind: row.read<String>('kind'),
              amountMinor: row.read<int>('amount_minor'),
              occurredAt: row.read<DateTime>('occurred_at'),
              title: row.read<String>('title'),
              accountName: row.read<String>('account_name'),
              destinationName: row.readNullable<String>('destination_name'),
              categoryId: row.readNullable<String>('category_id'),
              accountId: row.readNullable<String>('account_id'),
              destinationAccountId: row.readNullable<String>(
                'destination_account_id',
              ),
              note: row.readNullable<String>('note'),
            ),
          )
          .toList(),
    );
  }

  Stream<List<ActivityEntry>> watchAccountActivityEntries(String accountId) {
    const sql = '''
SELECT lt.id, lt.type AS kind, lt.amount_minor, lt.occurred_at, lt.note,
       c.name AS title, a.name AS account_name, NULL AS destination_name,
       lt.category_id, lt.account_id, NULL AS destination_account_id
FROM ledger_transactions lt
JOIN categories c ON c.id = lt.category_id
JOIN accounts a ON a.id = lt.account_id
WHERE lt.account_id = ?
UNION ALL
SELECT t.id, 'transfer' AS kind, t.amount_minor, t.occurred_at, t.note,
       'Transfer' AS title, source.name AS account_name,
       destination.name AS destination_name, NULL AS category_id,
       t.from_account_id AS account_id, t.to_account_id AS destination_account_id
FROM transfers t
JOIN accounts source ON source.id = t.from_account_id
JOIN accounts destination ON destination.id = t.to_account_id
WHERE t.from_account_id = ? OR t.to_account_id = ?
UNION ALL
SELECT adjustment.id,
       CASE WHEN adjustment.difference_minor >= 0
            THEN 'adjustment_in' ELSE 'adjustment_out' END AS kind,
       ABS(adjustment.difference_minor) AS amount_minor,
       adjustment.created_at AS occurred_at, adjustment.note,
       'Balance adjustment' AS title, account.name AS account_name,
       NULL AS destination_name, NULL AS category_id,
       adjustment.account_id AS account_id, NULL AS destination_account_id
FROM account_balance_adjustments adjustment
JOIN accounts account ON account.id = adjustment.account_id
WHERE adjustment.account_id = ?
ORDER BY occurred_at DESC
''';
    return customSelect(
      sql,
      variables: [
        Variable.withString(accountId),
        Variable.withString(accountId),
        Variable.withString(accountId),
        Variable.withString(accountId),
      ],
      readsFrom: {
        ledgerTransactions,
        transfers,
        categories,
        accounts,
        accountBalanceAdjustments,
      },
    ).watch().map(
      (rows) => rows
          .map(
            (row) => ActivityEntry(
              id: row.read<String>('id'),
              kind: row.read<String>('kind'),
              amountMinor: row.read<int>('amount_minor'),
              occurredAt: row.read<DateTime>('occurred_at'),
              title: row.read<String>('title'),
              accountName: row.read<String>('account_name'),
              destinationName: row.readNullable<String>('destination_name'),
              categoryId: row.readNullable<String>('category_id'),
              accountId: row.readNullable<String>('account_id'),
              destinationAccountId: row.readNullable<String>(
                'destination_account_id',
              ),
              note: row.readNullable<String>('note'),
            ),
          )
          .toList(),
    );
  }

  Future<List<AccountBalanceSummary>> accountBalances({
    bool includeArchived = false,
  }) async {
    final accountQuery = select(accounts);
    if (!includeArchived) {
      accountQuery.where((row) => row.archivedAt.isNull());
    }
    accountQuery.orderBy([
      (row) => OrderingTerm.asc(row.archivedAt),
      (row) => OrderingTerm.asc(row.createdAt),
    ]);
    final activeAccounts = await accountQuery.get();
    final transactions = await select(ledgerTransactions).get();
    final allTransfers = await select(transfers).get();
    final allAdjustments = await select(accountBalanceAdjustments).get();

    return activeAccounts.map((account) {
      var balance = account.openingBalanceMinor;
      for (final entry in transactions.where(
        (item) => item.accountId == account.id,
      )) {
        balance += entry.type == 'income'
            ? entry.amountMinor
            : -entry.amountMinor;
      }
      for (final transfer in allTransfers) {
        if (transfer.fromAccountId == account.id) {
          balance -= transfer.amountMinor;
        }
        if (transfer.toAccountId == account.id) {
          balance += transfer.amountMinor;
        }
      }
      for (final adjustment in allAdjustments.where(
        (item) => item.accountId == account.id,
      )) {
        balance += adjustment.differenceMinor;
      }
      return AccountBalanceSummary(account: account, balanceMinor: balance);
    }).toList();
  }

  Future<List<BudgetProgress>> budgetProgressForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final budgetRows = await (select(budgets).join([
      innerJoin(categories, categories.id.equalsExp(budgets.categoryId)),
    ])..where(budgets.periodStart.equals(start))).get();

    final result = <BudgetProgress>[];
    for (final row in budgetRows) {
      final budget = row.readTable(budgets);
      final category = row.readTable(categories);
      final transactions =
          await (select(ledgerTransactions)..where(
                (entry) =>
                    entry.type.equals('expense') &
                    entry.categoryId.equals(budget.categoryId) &
                    entry.occurredAt.isBiggerOrEqualValue(start) &
                    entry.occurredAt.isSmallerThanValue(end),
              ))
              .get();
      result.add(
        BudgetProgress(
          budget: budget,
          categoryName: category.name,
          categoryColorValue: category.colorValue,
          spentMinor: transactions.fold(
            0,
            (sum, item) => sum + item.amountMinor,
          ),
        ),
      );
    }
    result.sort((a, b) => b.fraction.compareTo(a.fraction));
    return result;
  }

  Future<ExpenseReport> expenseReport(ExpensePeriod period) async {
    final totals = await totalsFor(period);
    final previousTotals = await totalsFor(period.previous);
    final rows =
        await (select(ledgerTransactions).join([
              innerJoin(
                categories,
                categories.id.equalsExp(ledgerTransactions.categoryId),
              ),
            ])..where(
              ledgerTransactions.type.equals('expense') &
                  ledgerTransactions.occurredAt.isBiggerOrEqualValue(
                    period.startInclusive,
                  ) &
                  ledgerTransactions.occurredAt.isSmallerThanValue(
                    period.endExclusive,
                  ),
            ))
            .get();
    final categoryTotals = <String, (String, int, int)>{};
    final trendTotals = <int, (String, int)>{};
    for (final row in rows) {
      final entry = row.readTable(ledgerTransactions);
      final category = row.readTable(categories);
      final existing = categoryTotals[category.id];
      categoryTotals[category.id] = (
        category.name,
        category.colorValue,
        (existing?.$3 ?? 0) + entry.amountMinor,
      );
      final (key, label) = _trendBucket(period.kind, entry.occurredAt);
      final trend = trendTotals[key];
      trendTotals[key] = (label, (trend?.$2 ?? 0) + entry.amountMinor);
    }
    final categoryResult =
        categoryTotals.values
            .map(
              (item) => CategorySpending(
                name: item.$1,
                colorValue: item.$2,
                amountMinor: item.$3,
              ),
            )
            .toList()
          ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    final trendResult =
        trendTotals.entries
            .map(
              (entry) => SpendingTrendPoint(
                label: entry.value.$1,
                amountMinor: entry.value.$2,
                sortKey: entry.key,
              ),
            )
            .toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return ExpenseReport(
      totals: totals,
      previousTotals: previousTotals,
      categories: categoryResult,
      trend: trendResult,
      transactionCount: rows.length,
    );
  }

  (int, String) _trendBucket(ExpensePeriodKind kind, DateTime date) =>
      switch (kind) {
        ExpensePeriodKind.day => (
          date.hour,
          '${date.hour.toString().padLeft(2, '0')}:00',
        ),
        ExpensePeriodKind.year => (date.month, _monthLabel(date.month)),
        ExpensePeriodKind.week ||
        ExpensePeriodKind.month ||
        ExpensePeriodKind.custom => (
          date.year * 10000 + date.month * 100 + date.day,
          '${date.month}/${date.day}',
        ),
      };

  String _monthLabel(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

  Future<PeriodTotals> totalsFor(ExpensePeriod period) async {
    final rows =
        await (select(ledgerTransactions)..where(
              (row) =>
                  row.occurredAt.isBiggerOrEqualValue(period.startInclusive) &
                  row.occurredAt.isSmallerThanValue(period.endExclusive),
            ))
            .get();
    var income = 0;
    var expense = 0;
    for (final row in rows) {
      if (row.type == 'income') {
        income += row.amountMinor;
      } else if (row.type == 'expense') {
        expense += row.amountMinor;
      }
    }
    return PeriodTotals(incomeMinor: income, expenseMinor: expense);
  }
}
