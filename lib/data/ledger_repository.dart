import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database/app_database.dart';

enum LedgerEntryType { income, expense }

final class LedgerRepository {
  LedgerRepository(this.database) : _uuid = const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Future<String> createEntry({
    required LedgerEntryType type,
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime occurredAt,
    String? note,
  }) async {
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(accountId))).getSingleOrNull();
    final category = await (database.select(
      database.categories,
    )..where((row) => row.id.equals(categoryId))).getSingleOrNull();
    if (account == null) throw ArgumentError.value(accountId, 'accountId');
    if (category == null || category.type != type.name) {
      throw ArgumentError.value(categoryId, 'categoryId');
    }

    final id = _uuid.v4();
    await database
        .into(database.ledgerTransactions)
        .insert(
          LedgerTransactionsCompanion.insert(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            type: type.name,
            amountMinor: amountMinor,
            occurredAt: occurredAt,
            note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
          ),
        );
    return id;
  }

  Future<String> createTransfer({
    required int amountMinor,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    String? note,
  }) async {
    if (amountMinor <= 0) throw ArgumentError.value(amountMinor, 'amountMinor');
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Source and destination accounts must differ.');
    }

    return database.transaction(() async {
      final accountRows = await (database.select(
        database.accounts,
      )..where((row) => row.id.isIn([fromAccountId, toAccountId]))).get();
      if (accountRows.length != 2) throw ArgumentError('Account not found.');
      if (accountRows.first.currencyCode != accountRows.last.currencyCode) {
        throw ArgumentError('Cross-currency transfers are not supported.');
      }
      final id = _uuid.v4();
      await database
          .into(database.transfers)
          .insert(
            TransfersCompanion.insert(
              id: id,
              fromAccountId: fromAccountId,
              toAccountId: toAccountId,
              amountMinor: amountMinor,
              occurredAt: occurredAt,
              note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
            ),
          );
      return id;
    });
  }

  Future<void> deleteEntry(String id) async {
    await (database.delete(
      database.ledgerTransactions,
    )..where((row) => row.id.equals(id))).go();
  }
}
