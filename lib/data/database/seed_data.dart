import 'package:drift/drift.dart';

import 'app_database.dart';

Future<void> seedDatabase(AppDatabase database) async {
  if (await database.select(database.accounts).getSingleOrNull() != null) {
    return;
  }

  final now = DateTime.now();
  await database.transaction(() async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account-cash',
            name: 'Cash',
            openingBalanceDate: now,
            openingBalanceMinor: const Value(0),
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'account-bank',
            name: 'Bank',
            typeName: const Value('Bank'),
            openingBalanceDate: now,
            openingBalanceMinor: const Value(0),
            iconKey: const Value('account_balance'),
          ),
        );

    const defaults = <(String, String, String, int)>[
      ('category-food', 'Food', 'restaurant', 0xFFD86464),
      ('category-transport', 'Transport', 'directions_bus', 0xFF5B8DEF),
      ('category-bills', 'Bills', 'receipt', 0xFFC28732),
      ('category-shopping', 'Shopping', 'shopping_bag', 0xFF7E6BC4),
      ('category-health', 'Health', 'favorite', 0xFF3F8F70),
    ];
    for (final item in defaults) {
      await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              id: item.$1,
              name: item.$2,
              type: 'expense',
              iconKey: item.$3,
              colorValue: item.$4,
              isDefault: const Value(true),
            ),
          );
    }
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'category-salary',
            name: 'Salary',
            type: 'income',
            iconKey: 'payments',
            colorValue: 0xFF3F8F70,
            isDefault: const Value(true),
          ),
        );
  });
}
