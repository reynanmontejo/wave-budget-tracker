import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database/app_database.dart';

final class BudgetRepository {
  BudgetRepository(this.database) : _uuid = const Uuid();
  final AppDatabase database;
  final Uuid _uuid;

  Future<void> setMonthlyBudget({
    required String categoryId,
    required DateTime month,
    required int limitMinor,
  }) async {
    if (limitMinor <= 0) {
      throw ArgumentError('Budget limit must be greater than zero.');
    }
    final category = await (database.select(
      database.categories,
    )..where((row) => row.id.equals(categoryId))).getSingleOrNull();
    if (category == null ||
        category.archivedAt != null ||
        category.type != 'expense') {
      throw ArgumentError('Choose an expense category.');
    }
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final existing =
        await (database.select(database.budgets)..where(
              (row) =>
                  row.categoryId.equals(categoryId) &
                  row.periodStart.equals(start),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: _uuid.v4(),
              categoryId: categoryId,
              periodStart: start,
              periodEnd: end,
              limitMinor: limitMinor,
            ),
          );
    } else {
      await (database.update(
        database.budgets,
      )..where((row) => row.id.equals(existing.id))).write(
        BudgetsCompanion(
          limitMinor: Value(limitMinor),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
