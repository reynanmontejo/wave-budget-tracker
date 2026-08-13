import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/theme/wave_theme.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/database/seed_data.dart';
import 'package:wave/data/providers.dart';
import 'package:wave/features/accounts/accounts_screen.dart';
import 'package:wave/features/transactions/add_transaction_sheet.dart';

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

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

  testWidgets('saves an expense through the entry sheet', (tester) async {
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
    await tester.tap(find.widgetWithText(FilledButton, 'Save expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
