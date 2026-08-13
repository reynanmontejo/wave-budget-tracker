import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database/app_database.dart';

enum SavingsGoalStatus { active, completed, archived }

final class SavingsGoalProgress {
  const SavingsGoalProgress({required this.goal, required this.savedMinor});

  final SavingsGoal goal;
  final int savedMinor;
  int get remainingMinor =>
      (goal.targetMinor - savedMinor).clamp(0, goal.targetMinor);
  double get fraction =>
      goal.targetMinor == 0 ? 0 : savedMinor / goal.targetMinor;
}

final class SavingsRepository {
  SavingsRepository(this.database) : _uuid = const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Stream<List<SavingsGoalProgress>> watchGoals({bool includeArchived = false}) {
    return database
        .customSelect(
          'SELECT 1',
          readsFrom: {database.savingsGoals, database.savingsContributions},
        )
        .watch()
        .asyncMap((_) async {
          final goalQuery = database.select(database.savingsGoals)
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
          if (!includeArchived) {
            goalQuery.where(
              (row) => row.status.isNotValue(SavingsGoalStatus.archived.name),
            );
          }
          final goals = await goalQuery.get();
          final contributions = await database
              .select(database.savingsContributions)
              .get();
          return goals.map((goal) {
            final saved = contributions
                .where(
                  (item) => item.goalId == goal.id && item.reversedAt == null,
                )
                .fold<int>(0, (sum, item) => sum + item.amountMinor);
            return SavingsGoalProgress(goal: goal, savedMinor: saved);
          }).toList();
        });
  }

  Stream<List<SavingsContribution>> watchContributions(String goalId) =>
      (database.select(database.savingsContributions)
            ..where((row) => row.goalId.equals(goalId))
            ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
          .watch();

  Future<String> createGoal({
    required String name,
    required int targetMinor,
    DateTime? targetDate,
    String? linkedAccountId,
    int colorValue = 0xFF269CA3,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || targetMinor <= 0) {
      throw ArgumentError('Enter a goal name and positive target.');
    }
    await _validateAccount(linkedAccountId);
    final id = _uuid.v4();
    await database
        .into(database.savingsGoals)
        .insert(
          SavingsGoalsCompanion.insert(
            id: id,
            name: cleanName,
            targetMinor: targetMinor,
            targetDate: Value(targetDate),
            linkedAccountId: Value(linkedAccountId),
            colorValue: Value(colorValue),
          ),
        );
    return id;
  }

  Future<void> updateGoal({
    required String id,
    required String name,
    required int targetMinor,
    DateTime? targetDate,
    String? linkedAccountId,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || targetMinor <= 0) {
      throw ArgumentError('Enter a goal name and positive target.');
    }
    await _validateAccount(linkedAccountId);
    final changed =
        await (database.update(
          database.savingsGoals,
        )..where((row) => row.id.equals(id))).write(
          SavingsGoalsCompanion(
            name: Value(cleanName),
            targetMinor: Value(targetMinor),
            targetDate: Value(targetDate),
            linkedAccountId: Value(linkedAccountId),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed != 1) throw ArgumentError('Savings goal not found.');
  }

  Future<void> setStatus(String id, SavingsGoalStatus status) async {
    final changed =
        await (database.update(
          database.savingsGoals,
        )..where((row) => row.id.equals(id))).write(
          SavingsGoalsCompanion(
            status: Value(status.name),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed != 1) throw ArgumentError('Savings goal not found.');
  }

  Future<String> addContribution({
    required String goalId,
    required int amountMinor,
    required DateTime occurredAt,
    String? note,
  }) async {
    if (amountMinor <= 0) throw ArgumentError('Contribution must be positive.');
    final goal = await _goal(goalId);
    if (goal.status != SavingsGoalStatus.active.name) {
      throw StateError('Contributions require an active goal.');
    }
    final id = _uuid.v4();
    await database
        .into(database.savingsContributions)
        .insert(
          SavingsContributionsCompanion.insert(
            id: id,
            goalId: goalId,
            amountMinor: amountMinor,
            occurredAt: occurredAt,
            note: Value(_cleanNote(note)),
          ),
        );
    return id;
  }

  Future<void> reverseContribution(String id) async {
    final contribution = await (database.select(
      database.savingsContributions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (contribution == null) throw ArgumentError('Contribution not found.');
    if (contribution.reversedAt != null) {
      throw StateError('Contribution was already reversed.');
    }
    await (database.update(
      database.savingsContributions,
    )..where((row) => row.id.equals(id))).write(
      SavingsContributionsCompanion(reversedAt: Value(DateTime.now())),
    );
  }

  Future<SavingsGoal> _goal(String id) async {
    final goal = await (database.select(
      database.savingsGoals,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (goal == null) throw ArgumentError('Savings goal not found.');
    return goal;
  }

  Future<void> _validateAccount(String? id) async {
    if (id == null) return;
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (account == null || account.archivedAt != null) {
      throw ArgumentError('Choose an active linked account.');
    }
  }

  static String? _cleanNote(String? note) {
    final value = note?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
