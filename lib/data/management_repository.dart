import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database/app_database.dart';

final class ManagementRepository {
  ManagementRepository(this.database) : _uuid = const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Future<String> createAccount({
    required String name,
    required String typeName,
    required int openingBalanceMinor,
    DateTime? openingBalanceDate,
  }) async {
    final cleanName = name.trim();
    final cleanType = typeName.trim();
    if (cleanName.isEmpty) throw ArgumentError('Account name is required.');
    if (cleanType.isEmpty) throw ArgumentError('Account type is required.');
    if (openingBalanceMinor < 0) {
      throw ArgumentError('Opening balance cannot be negative.');
    }
    final duplicate =
        await (database.select(database.accounts)..where(
              (row) =>
                  row.archivedAt.isNull() &
                  row.name.lower().equals(cleanName.toLowerCase()),
            ))
            .getSingleOrNull();
    if (duplicate != null) {
      throw ArgumentError('An active account already uses this name.');
    }

    final id = _uuid.v4();
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            name: cleanName,
            typeName: Value(cleanType),
            openingBalanceMinor: Value(openingBalanceMinor),
            openingBalanceDate: openingBalanceDate ?? DateTime.now(),
          ),
        );
    return id;
  }

  Future<void> archiveAccount(String id) async {
    final active = await (database.select(
      database.accounts,
    )..where((row) => row.archivedAt.isNull())).get();
    if (active.length <= 1) {
      throw StateError('Wave needs at least one active account.');
    }
    await (database.update(
      database.accounts,
    )..where((row) => row.id.equals(id))).write(
      AccountsCompanion(
        archivedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String typeName,
    required int openingBalanceMinor,
  }) async {
    final cleanName = name.trim();
    final cleanType = typeName.trim();
    if (cleanName.isEmpty || cleanType.isEmpty) {
      throw ArgumentError('Account name and type are required.');
    }
    if (openingBalanceMinor < 0) {
      throw ArgumentError('Opening balance cannot be negative.');
    }
    final duplicate =
        await (database.select(database.accounts)..where(
              (row) =>
                  row.id.equals(id).not() &
                  row.archivedAt.isNull() &
                  row.name.lower().equals(cleanName.toLowerCase()),
            ))
            .getSingleOrNull();
    if (duplicate != null) {
      throw ArgumentError('An active account already uses this name.');
    }
    final changed =
        await (database.update(
          database.accounts,
        )..where((row) => row.id.equals(id))).write(
          AccountsCompanion(
            name: Value(cleanName),
            typeName: Value(cleanType),
            openingBalanceMinor: Value(openingBalanceMinor),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed != 1) throw ArgumentError('Account not found.');
  }

  Future<String> createCategory({
    required String name,
    required String type,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Category name is required.');
    if (type != 'income' && type != 'expense') {
      throw ArgumentError('Invalid category type.');
    }
    final duplicate =
        await (database.select(database.categories)..where(
              (row) =>
                  row.archivedAt.isNull() &
                  row.type.equals(type) &
                  row.name.lower().equals(cleanName.toLowerCase()),
            ))
            .getSingleOrNull();
    if (duplicate != null) throw ArgumentError('This category already exists.');

    final id = _uuid.v4();
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: cleanName,
            type: type,
            iconKey: type == 'income' ? 'payments' : 'label',
            colorValue: type == 'income' ? 0xFF3F8F70 : 0xFF5B8DEF,
          ),
        );
    return id;
  }

  Future<void> archiveCategory(String id) async {
    await (database.update(
      database.categories,
    )..where((row) => row.id.equals(id))).write(
      CategoriesCompanion(
        archivedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateCategory({
    required String id,
    required String name,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Category name is required.');
    final current = await (database.select(
      database.categories,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (current == null) throw ArgumentError('Category not found.');
    final duplicate =
        await (database.select(database.categories)..where(
              (row) =>
                  row.id.equals(id).not() &
                  row.archivedAt.isNull() &
                  row.type.equals(current.type) &
                  row.name.lower().equals(cleanName.toLowerCase()),
            ))
            .getSingleOrNull();
    if (duplicate != null) throw ArgumentError('This category already exists.');
    await (database.update(
      database.categories,
    )..where((row) => row.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(cleanName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
