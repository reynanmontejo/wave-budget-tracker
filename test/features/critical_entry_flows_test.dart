import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/theme/wave_theme.dart';
import 'package:wave/core/period/expense_period.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/budget_repository.dart';
import 'package:wave/data/ledger_repository.dart';
import 'package:wave/data/management_repository.dart';
import 'package:wave/data/providers.dart';
import 'package:wave/data/schedule_repository.dart';
import 'package:wave/features/accounts/accounts_screen.dart';
import 'package:wave/features/home/home_screen.dart';
import 'package:wave/features/insights/insights_hub_screen.dart';
import 'package:wave/features/plan/plan_hub_screen.dart';
import 'package:wave/features/transactions/add_transaction_sheet.dart';
import 'package:wave/features/planned/planned_screen.dart';
import 'package:wave/features/reports/reports_screen.dart';
import 'package:wave/features/shell/app_shell.dart';

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

  tearDown(() async {
    await database.close();
  });

  Widget app(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: MaterialApp(theme: WaveTheme.light, home: child),
  );

  Future<void> openEntrySheet(
    WidgetTester tester,
    EntryMode mode, {
    bool largeText = false,
  }) async {
    Widget launcher = Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => AddTransactionSheet(initialMode: mode),
            ),
            child: const Text('Open entry'),
          ),
        ),
      ),
    );
    if (largeText) {
      launcher = MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: launcher,
      );
    }
    await tester.pumpWidget(app(launcher));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Open entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

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
    await tester.scrollUntilVisible(
      find.text('GCash'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GCash'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Home presents compact account cards and account entry points', (
    tester,
  ) async {
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('My accounts'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  testWidgets('Home e-wallet card fits a narrow screen with large text', (
    tester,
  ) async {
    await ManagementRepository(database).createAccount(
      name: 'Daily wallet with a long name',
      typeName: 'E-wallet',
      openingBalanceMinor: 150000,
      walletProviderName: 'GCash',
      walletProviderKey: 'gcash',
      walletIdentifierSuffix: '42',
    );
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
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('light-home')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('home-account-cards')),
      const Offset(-500, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('GCash'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason: layoutError is FlutterError ? layoutError.toStringDeep() : null,
    );
    await disposeApp(tester);
  });

  testWidgets('creates and reconciles a manual e-wallet', (tester) async {
    await tester.pumpWidget(app(const AccountsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('E-wallets ('));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add e-wallet'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Wallet nickname'),
      'Daily wallet',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Current wallet value'),
      '1500.00',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Last four digits (optional)'),
      '42',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Manual • no provider connection'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm and add'));
    await tester.pumpAndSettle();

    expect(find.text('Daily wallet'), findsOneWidget);
    expect(find.textContaining('GCash'), findsWidgets);
    await tester.tap(find.text('Daily wallet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Manual'), findsWidgets);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reconcile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Value shown in wallet'),
      '1600.00',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Review adjustment'));
    await tester.pumpAndSettle();
    expect(find.text('Excluded from income and expenses'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm update'));
    await tester.pumpAndSettle();

    final wallet = await (database.select(
      database.accounts,
    )..where((row) => row.name.equals('Daily wallet'))).getSingle();
    final balances = await database.accountBalances();
    expect(
      balances.singleWhere((item) => item.account.id == wallet.id).balanceMinor,
      160000,
    );
    expect(
      await database.select(database.accountBalanceAdjustments).get(),
      hasLength(1),
    );
    await disposeApp(tester);
  });

  testWidgets('reads account details and confirms account updates', (
    tester,
  ) async {
    await tester.pumpWidget(app(const AccountsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    expect(find.text('OPENING BALANCE'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Account name'),
      'Pocket Cash',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm account changes'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('account-cash'))).getSingle();
    expect(account.name, 'Pocket Cash');
    expect(find.text('Pocket Cash'), findsWidgets);
    await disposeApp(tester);
  });

  testWidgets('archives and restores an account with confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(app(const AccountsScreen()));
    await tester.pumpAndSettle();

    final actions = find.byTooltip('Account actions');
    await tester.ensureVisible(actions.at(1));
    await tester.tap(actions.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(find.text('Archive Bank?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    var bank = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('account-bank'))).getSingle();
    expect(bank.archivedAt, isNotNull);

    await tester.tap(find.textContaining('Archived ('));
    await tester.pumpAndSettle();
    final archivedActions = find.byTooltip('Account actions');
    await tester.tap(archivedActions.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    bank = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('account-bank'))).getSingle();
    expect(bank.archivedAt, isNull);
    await disposeApp(tester);
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
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
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

  testWidgets('saves and can undo income through the redesigned flow', (
    tester,
  ) async {
    await openEntrySheet(tester, EntryMode.income);
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm income'));
    await tester.pump(const Duration(milliseconds: 300));

    final entries = await database.select(database.ledgerTransactions).get();
    expect(entries.single.type, 'income');
    expect(entries.single.amountMinor, 500000);
    expect(find.text('Income added'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    await disposeApp(tester);
  });

  testWidgets('transfer flow supports account swap and Undo', (tester) async {
    await openEntrySheet(tester, EntryMode.transfer);
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '250');
    await tester.tap(find.byTooltip('Swap accounts'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm transfer'));
    await tester.pump(const Duration(milliseconds: 300));

    final transfers = await database.select(database.transfers).get();
    expect(transfers.single.fromAccountId, 'account-bank');
    expect(transfers.single.toAccountId, 'account-cash');
    expect(find.text('Transfer added'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    expect(await database.select(database.transfers).get(), isEmpty);
    await disposeApp(tester);
  });

  testWidgets('transaction flow fits a narrow screen at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openEntrySheet(tester, EntryMode.expense, largeText: true);

    expect(find.text('Add transaction'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '20');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Expense details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  testWidgets('shell navigation fully hides the outgoing page', (tester) async {
    await tester.pumpWidget(app(const AppShell()));
    await tester.pump(const Duration(milliseconds: 300));

    final homePage = find.byKey(const ValueKey('shell-page-0'));
    final planPage = find.byKey(const ValueKey('shell-page-3'));
    expect(
      tester.renderObject<RenderAnimatedOpacity>(homePage).opacity.value,
      1,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Plan'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      tester.renderObject<RenderAnimatedOpacity>(homePage).opacity.value,
      0,
    );
    expect(
      tester.renderObject<RenderAnimatedOpacity>(planPage).opacity.value,
      1,
    );
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  testWidgets('Light Home prioritizes only the essential dashboard content', (
    tester,
  ) async {
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('TOTAL BALANCE'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Net'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Quick actions'), findsNothing);
    expect(find.text('Coming up'), findsNothing);
    expect(find.text('Daily average'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeApp(tester);
  });

  testWidgets('Light Home exposes concise protected financial semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.bySemanticsLabel(RegExp(r'^Total balance .*active accounts$')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'^Income: ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Expenses: ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Net: ')), findsOneWidget);

    await tester.tap(find.byTooltip('Hide balances'));
    await tester.pump();
    expect(
      find.bySemanticsLabel(RegExp(r'^Total balance hidden, ')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Income: hidden'), findsOneWidget);
    expect(find.bySemanticsLabel('Expenses: hidden'), findsOneWidget);
    expect(find.bySemanticsLabel('Net: hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);

    semantics.dispose();
    await disposeApp(tester);
  });

  testWidgets('Light Home remains usable at 320 pixels and 200 percent text', (
    tester,
  ) async {
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
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TOTAL BALANCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Recent activity'),
      180,
      scrollable: verticalScrollable.first,
    );
    expect(find.text('Recent activity'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason: layoutError is FlutterError ? layoutError.toStringDeep() : null,
    );
    await disposeApp(tester);
  });

  testWidgets('Light Home prioritizes overdue plans over budget alerts', (
    tester,
  ) async {
    final now = DateTime.now();
    await BudgetRepository(database).setMonthlyBudget(
      categoryId: 'category-food',
      month: now,
      limitMinor: 1000,
    );
    await LedgerRepository(database).createEntry(
      type: LedgerEntryType.expense,
      amountMinor: 1200,
      accountId: 'account-cash',
      categoryId: 'category-food',
      occurredAt: now,
    );
    await ScheduleRepository(database).create(
      type: 'expense',
      amountMinor: 25000,
      accountId: 'account-cash',
      categoryId: 'category-food',
      nextDueAt: now.subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Planned expense overdue'), findsOneWidget);
    expect(find.text('Budget exceeded'), findsNothing);
    await tester.ensureVisible(find.text('Planned expense overdue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planned expense overdue'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('Plan hub exposes upcoming, budgets, and savings', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PlanHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming activity'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Budgets'), 180);
    expect(find.text('Budgets'), findsOneWidget);
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
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
