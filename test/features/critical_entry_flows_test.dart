import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/theme/wave_theme.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/providers.dart';
import 'package:wave/features/accounts/accounts_screen.dart';
import 'package:wave/features/insights/insights_hub_screen.dart';
import 'package:wave/features/plan/plan_hub_screen.dart';
import 'package:wave/features/transactions/add_transaction_sheet.dart';
import 'package:wave/features/planned/planned_screen.dart';
import 'package:wave/features/reports/reports_screen.dart';

void main() {
  late AppDatabase database;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await seedDatabase(database);
  });

  Widget app(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: MaterialApp(theme: WaveTheme.light, home: child),
  );

  testWidgets('creates an account through the account dialog', (tester) async {
    await tester.pumpWidget(app(const AccountsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Add account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.widgetWithText(TextField, 'Account name'),
      'GCash',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Opening balance'),
      '1250.50',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm and add'));
    await tester.pumpAndSettle();

    final accounts = await database.select(database.accounts).get();
    final gcash = accounts.singleWhere((account) => account.name == 'GCash');
    expect(gcash.openingBalanceMinor, 125050);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('GCash'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'account flow remains usable on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            theme: WaveTheme.light,
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: AccountsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Account name'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
      final layoutError = tester.takeException();
      expect(
        layoutError,
        isNull,
        reason: layoutError is FlutterError ? layoutError.toStringDeep() : null,
      );
    },
  );

  testWidgets('saves and can undo an expense through the entry sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) =>
                      const AddTransactionSheet(initialMode: EntryMode.expense),
                ),
                child: const Text('Open entry'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Open entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.widgetWithText(TextField, '0.00'), '85.25');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('₱85.25'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    final entries = await tester.runAsync(
      () => database
          .select(database.ledgerTransactions)
          .get()
          .timeout(const Duration(seconds: 5)),
    );
    expect(entries, isNotNull);
    final savedEntries = entries!;
    expect(savedEntries, hasLength(1));
    expect(savedEntries.single.type, 'expense');
    expect(savedEntries.single.amountMinor, 8525);
    expect(savedEntries.single.accountId, 'account-cash');
    expect(savedEntries.single.categoryId, isNotEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    final remaining = await tester.runAsync(
      () => database.select(database.ledgerTransactions).get(),
    );
    expect(remaining, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Plan hub exposes upcoming, budgets, and savings', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PlanHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming activity'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Budgets'), 180);
    expect(find.text('Budgets'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Savings goals'), 180);
    expect(find.text('Savings goals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Insights hub distinguishes forecasts from actual reports', (
    tester,
  ) async {
    await tester.pumpWidget(app(const InsightsHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Cash flow'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reports'), 180);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('FORECAST'), findsOneWidget);
    expect(find.text('ACTUAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reports accepts the shared custom period', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          selectedPeriodKindProvider.overrideWith(
            (ref) => ExpensePeriodKind.custom,
          ),
          selectedCustomPeriodProvider.overrideWith(
            (ref) => ExpensePeriod.custom(
              DateTime(2026, 8, 1),
              DateTime(2026, 8, 10),
            ),
          ),
        ],
        child: MaterialApp(theme: WaveTheme.light, home: const ReportsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final selector = tester.widget<DropdownButtonFormField<ExpensePeriodKind>>(
      find.byType(DropdownButtonFormField<ExpensePeriodKind>),
    );
    expect(selector.initialValue, ExpensePeriodKind.custom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planned form resets category when type changes', (tester) async {
    await tester.pumpWidget(app(const PlannedScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Plan activity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Income'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final fields = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    expect(fields, hasLength(2));
    expect(fields[1].initialValue, 'category-salary');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
