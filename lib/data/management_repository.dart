import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database/app_database.dart';
import 'wallet_providers.dart';

const supportedAccountTypes = <String>[
  'Cash',
  'Bank',
  'E-wallet',
  'Savings',
  'Investment',
];

final class AccountUsageSummary {
  const AccountUsageSummary({
    required this.transactions,
    required this.transfers,
    required this.schedules,
    required this.activeSchedules,
    required this.linkedGoals,
    required this.adjustments,
    required this.balanceMinor,
  });

  final int transactions;
  final int transfers;
  final int schedules;
  final int activeSchedules;
  final int linkedGoals;
  final int adjustments;
  final int balanceMinor;

  bool get hasHistory =>
      transactions > 0 ||
      transfers > 0 ||
      schedules > 0 ||
      linkedGoals > 0 ||
      adjustments > 0;
  bool get canDeletePermanently => !hasHistory && balanceMinor == 0;
}

final class ManagementRepository {
  ManagementRepository(this.database) : _uuid = const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Future<String> createAccount({
    required String name,
    required String typeName,
    required int openingBalanceMinor,
    DateTime? openingBalanceDate,
    String currencyCode = 'PHP',
    String iconKey = 'wallet',
    int colorValue = 0xFF5B8DEF,
    bool includeInNetWorth = true,
    String? walletProviderName,
    String? walletProviderKey,
    String? walletIdentifierSuffix,
  }) async {
    final cleanName = name.trim();
    final cleanType = typeName.trim();
    final cleanCurrency = currencyCode.trim().toUpperCase();
    if (cleanName.isEmpty) throw ArgumentError('Account name is required.');
    _validateAccountType(cleanType);
    if (cleanCurrency.length != 3) {
      throw ArgumentError('Use a valid three-letter currency code.');
    }
    if (openingBalanceMinor < 0) {
      throw ArgumentError('Opening balance cannot be negative.');
    }
    final wallet = _validatedWalletFields(
      typeName: cleanType,
      providerName: cleanType == 'E-wallet'
          ? (walletProviderName?.trim().isNotEmpty ?? false)
                ? walletProviderName
                : cleanName
          : null,
      providerKey: walletProviderKey,
      identifierSuffix: walletIdentifierSuffix,
    );
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
            currencyCode: Value(cleanCurrency),
            openingBalanceMinor: Value(openingBalanceMinor),
            openingBalanceDate: openingBalanceDate ?? DateTime.now(),
            iconKey: Value(iconKey),
            colorValue: Value(colorValue),
            includeInNetWorth: Value(includeInNetWorth),
            walletProviderName: Value(wallet.providerName),
            walletProviderKey: Value(wallet.providerKey),
            walletIdentifierSuffix: Value(wallet.identifierSuffix),
            walletLastReconciledAt: Value(
              cleanType == 'E-wallet' ? DateTime.now() : null,
            ),
          ),
        );
    return id;
  }

  Future<void> archiveAccount(String id) async {
    await database.transaction(() async {
      final account = await _account(id);
      if (account.archivedAt != null) {
        throw StateError('This account is already archived.');
      }
      await _protectLastActiveAccount();
      final usage = await accountUsage(id);
      if (usage.activeSchedules > 0) {
        throw StateError(
          'Pause or reassign active planned transactions before archiving this account.',
        );
      }
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals(id))).write(
        AccountsCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> restoreAccount(String id) async {
    await database.transaction(() async {
      final account = await _account(id);
      if (account.archivedAt == null) {
        throw StateError('This account is already active.');
      }
      final duplicate =
          await (database.select(database.accounts)..where(
                (row) =>
                    row.id.equals(id).not() &
                    row.archivedAt.isNull() &
                    row.name.lower().equals(account.name.toLowerCase()),
              ))
              .getSingleOrNull();
      if (duplicate != null) {
        throw StateError(
          'Rename the active account named ${account.name} before restoring this one.',
        );
      }
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals(id))).write(
        AccountsCompanion(
          archivedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> deleteUnusedAccount(String id) async {
    await database.transaction(() async {
      final account = await _account(id);
      if (account.archivedAt == null) await _protectLastActiveAccount();
      final usage = await accountUsage(id);
      if (!usage.canDeletePermanently) {
        throw StateError(
          'Only an unused account with a zero balance can be permanently deleted. Archive this account instead.',
        );
      }
      final deleted = await (database.delete(
        database.accounts,
      )..where((row) => row.id.equals(id))).go();
      if (deleted != 1) throw ArgumentError('Account not found.');
    });
  }

  Future<AccountUsageSummary> accountUsage(String id) async {
    final account = await _account(id);
    final transactions = await (database.select(
      database.ledgerTransactions,
    )..where((row) => row.accountId.equals(id))).get();
    final transfers =
        await (database.select(database.transfers)..where(
              (row) =>
                  row.fromAccountId.equals(id) | row.toAccountId.equals(id),
            ))
            .get();
    final schedules = await (database.select(
      database.scheduledTransactions,
    )..where((row) => row.accountId.equals(id))).get();
    final goals = await (database.select(
      database.savingsGoals,
    )..where((row) => row.linkedAccountId.equals(id))).get();
    final adjustments = await (database.select(
      database.accountBalanceAdjustments,
    )..where((row) => row.accountId.equals(id))).get();
    var balance = account.openingBalanceMinor;
    for (final entry in transactions) {
      balance += entry.type == 'income'
          ? entry.amountMinor
          : -entry.amountMinor;
    }
    for (final transfer in transfers) {
      if (transfer.fromAccountId == id) balance -= transfer.amountMinor;
      if (transfer.toAccountId == id) balance += transfer.amountMinor;
    }
    for (final adjustment in adjustments) {
      balance += adjustment.differenceMinor;
    }
    return AccountUsageSummary(
      transactions: transactions.length,
      transfers: transfers.length,
      schedules: schedules.length,
      activeSchedules: schedules
          .where((item) => item.status == 'active')
          .length,
      linkedGoals: goals.length,
      adjustments: adjustments.length,
      balanceMinor: balance,
    );
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String typeName,
    required int openingBalanceMinor,
    DateTime? openingBalanceDate,
    String? iconKey,
    int? colorValue,
    bool? includeInNetWorth,
    String? walletProviderName,
    String? walletProviderKey,
    String? walletIdentifierSuffix,
  }) async {
    final cleanName = name.trim();
    final cleanType = typeName.trim();
    if (cleanName.isEmpty) throw ArgumentError('Account name is required.');
    _validateAccountType(cleanType);
    if (openingBalanceMinor < 0) {
      throw ArgumentError('Opening balance cannot be negative.');
    }
    final wallet = _validatedWalletFields(
      typeName: cleanType,
      providerName: walletProviderName,
      providerKey: walletProviderKey,
      identifierSuffix: walletIdentifierSuffix,
    );
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
            openingBalanceDate: openingBalanceDate == null
                ? const Value.absent()
                : Value(openingBalanceDate),
            iconKey: iconKey == null ? const Value.absent() : Value(iconKey),
            colorValue: colorValue == null
                ? const Value.absent()
                : Value(colorValue),
            includeInNetWorth: includeInNetWorth == null
                ? const Value.absent()
                : Value(includeInNetWorth),
            walletProviderName: Value(wallet.providerName),
            walletProviderKey: Value(wallet.providerKey),
            walletIdentifierSuffix: Value(wallet.identifierSuffix),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (changed != 1) throw ArgumentError('Account not found.');
  }

  Future<String?> reconcileAccountBalance({
    required String accountId,
    required int observedBalanceMinor,
    String? note,
  }) async {
    if (observedBalanceMinor < 0) {
      throw ArgumentError('Wallet value cannot be negative.');
    }
    return database.transaction(() async {
      final account = await _account(accountId);
      if (account.archivedAt != null) {
        throw StateError('Restore this wallet before reconciling its value.');
      }
      if (account.typeName != 'E-wallet') {
        throw ArgumentError('Only an e-wallet can use value reconciliation.');
      }
      final usage = await accountUsage(accountId);
      final difference = observedBalanceMinor - usage.balanceMinor;
      final now = DateTime.now();
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals(accountId))).write(
        AccountsCompanion(
          walletLastReconciledAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      if (difference == 0) return null;
      final id = _uuid.v4();
      await database
          .into(database.accountBalanceAdjustments)
          .insert(
            AccountBalanceAdjustmentsCompanion.insert(
              id: id,
              accountId: accountId,
              differenceMinor: difference,
              observedBalanceMinor: observedBalanceMinor,
              note: Value(_cleanOptional(note)),
              createdAt: Value(now),
            ),
          );
      return id;
    });
  }

  Future<String> reverseBalanceAdjustment(String adjustmentId) async {
    return database.transaction(() async {
      final adjustment = await (database.select(
        database.accountBalanceAdjustments,
      )..where((row) => row.id.equals(adjustmentId))).getSingleOrNull();
      if (adjustment == null) throw ArgumentError('Adjustment not found.');
      final account = await _account(adjustment.accountId);
      if (account.archivedAt != null) {
        throw StateError('Restore this wallet before undoing an adjustment.');
      }
      final usage = await accountUsage(adjustment.accountId);
      final inverse = -adjustment.differenceMinor;
      final id = _uuid.v4();
      final now = DateTime.now();
      await database
          .into(database.accountBalanceAdjustments)
          .insert(
            AccountBalanceAdjustmentsCompanion.insert(
              id: id,
              accountId: adjustment.accountId,
              differenceMinor: inverse,
              observedBalanceMinor: usage.balanceMinor + inverse,
              note: const Value('Undo balance adjustment'),
              createdAt: Value(now),
            ),
          );
      await (database.update(
        database.accounts,
      )..where((row) => row.id.equals(adjustment.accountId))).write(
        AccountsCompanion(
          walletLastReconciledAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return id;
    });
  }

  Future<Account> _account(String id) async {
    final account = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (account == null) throw ArgumentError('Account not found.');
    return account;
  }

  Future<void> _protectLastActiveAccount() async {
    final active = await (database.select(
      database.accounts,
    )..where((row) => row.archivedAt.isNull())).get();
    if (active.length <= 1) {
      throw StateError('Wave needs at least one active account.');
    }
  }

  void _validateAccountType(String type) {
    if (!supportedAccountTypes.contains(type)) {
      throw ArgumentError('Choose a supported account type.');
    }
  }

  ({String? providerName, String? providerKey, String? identifierSuffix})
  _validatedWalletFields({
    required String typeName,
    String? providerName,
    String? providerKey,
    String? identifierSuffix,
  }) {
    if (typeName != 'E-wallet') {
      return (providerName: null, providerKey: null, identifierSuffix: null);
    }
    final cleanProvider = providerName?.trim() ?? '';
    if (cleanProvider.isEmpty) {
      throw ArgumentError('Choose or enter an e-wallet provider.');
    }
    final cleanKey = providerKey?.trim().toLowerCase();
    if (cleanKey != null &&
        cleanKey.isNotEmpty &&
        walletProviderForKey(cleanKey) == null &&
        cleanKey != 'custom') {
      throw ArgumentError('Choose a supported provider preset or Custom.');
    }
    final cleanSuffix = identifierSuffix?.trim();
    if (cleanSuffix != null &&
        cleanSuffix.isNotEmpty &&
        !RegExp(r'^\d{1,4}$').hasMatch(cleanSuffix)) {
      throw ArgumentError('Wallet identifier must be the final four digits.');
    }
    return (
      providerName: cleanProvider,
      providerKey: cleanKey == null || cleanKey.isEmpty ? 'custom' : cleanKey,
      identifierSuffix: cleanSuffix == null || cleanSuffix.isEmpty
          ? null
          : cleanSuffix,
    );
  }

  String? _cleanOptional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
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
