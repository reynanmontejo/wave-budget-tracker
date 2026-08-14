import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wave/data/database/app_database.dart';

void main() {
  test('version 1 data survives migration to the current schema', () async {
    final directory = await Directory.systemTemp.createTemp('wave-migration-');
    final file = File('${directory.path}${Platform.pathSeparator}wave.sqlite');
    final legacy = sqlite.sqlite3.open(file.path);
    try {
      legacy.execute('''
CREATE TABLE accounts (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  type_name TEXT NOT NULL DEFAULT 'Cash',
  currency_code TEXT NOT NULL DEFAULT 'PHP',
  opening_balance_minor INTEGER NOT NULL DEFAULT 0,
  opening_balance_date INTEGER NOT NULL,
  icon_key TEXT NOT NULL DEFAULT 'wallet',
  color_value INTEGER NOT NULL DEFAULT 4284198383,
  include_in_net_worth INTEGER NOT NULL DEFAULT 1,
  archived_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE categories (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  icon_key TEXT NOT NULL,
  color_value INTEGER NOT NULL,
  is_default INTEGER NOT NULL DEFAULT 0,
  archived_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE ledger_transactions (
  id TEXT NOT NULL PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  category_id TEXT NOT NULL REFERENCES categories(id),
  type TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE transfers (
  id TEXT NOT NULL PRIMARY KEY,
  from_account_id TEXT NOT NULL REFERENCES accounts(id),
  to_account_id TEXT NOT NULL REFERENCES accounts(id),
  amount_minor INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE TABLE budgets (
  id TEXT NOT NULL PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES categories(id),
  period_type TEXT NOT NULL DEFAULT 'monthly',
  period_start INTEGER NOT NULL,
  period_end INTEGER NOT NULL,
  limit_minor INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(category_id, period_start, period_end)
);
''');
      final timestamp = DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000;
      legacy.execute(
        "INSERT INTO accounts VALUES ('legacy-account', 'Wallet', 'Cash', "
        "'PHP', 50000, $timestamp, 'wallet', 4284198383, 1, NULL, "
        "$timestamp, $timestamp)",
      );
      legacy.execute(
        "INSERT INTO categories VALUES ('legacy-category', 'Food', "
        "'expense', 'food', 4284198383, 1, NULL, $timestamp, $timestamp)",
      );
      legacy.execute(
        "INSERT INTO ledger_transactions VALUES ('legacy-entry', "
        "'legacy-account', 'legacy-category', 'expense', 1250, $timestamp, "
        "'Lunch', $timestamp, $timestamp)",
      );
      legacy.execute('PRAGMA user_version = 1');
    } finally {
      legacy.close();
    }

    final database = AppDatabase(NativeDatabase(file));
    try {
      final account = await database.select(database.accounts).getSingle();
      final entry = await database
          .select(database.ledgerTransactions)
          .getSingle();
      expect(database.schemaVersion, 4);
      expect(account.id, 'legacy-account');
      expect(account.openingBalanceMinor, 50000);
      expect(entry.id, 'legacy-entry');
      expect(entry.amountMinor, 1250);
      expect(await database.select(database.appPreferences).get(), isEmpty);
      expect(
        await database.select(database.scheduledTransactions).get(),
        isEmpty,
      );
      expect(await database.select(database.savingsGoals).get(), isEmpty);
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}
