import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wave/data/database/app_database.dart';
import 'package:wave/data/onboarding_repository.dart';

void main() {
  late AppDatabase database;
  late OnboardingRepository onboarding;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    onboarding = OnboardingRepository(database);
  });

  tearDown(() => database.close());

  test('first launch is incomplete before setup', () async {
    expect(await onboarding.isComplete(), isFalse);
  });

  test(
    'completion creates one chosen account and default categories',
    () async {
      await onboarding.complete(
        accountName: 'My GCash',
        accountType: 'E-wallet',
        openingBalanceMinor: 125050,
      );

      final accounts = await database.select(database.accounts).get();
      final categories = await database.select(database.categories).get();
      expect(accounts, hasLength(1));
      expect(accounts.single.name, 'My GCash');
      expect(accounts.single.openingBalanceMinor, 125050);
      expect(categories.length, greaterThanOrEqualTo(6));
      expect(await onboarding.isComplete(), isTrue);
    },
  );

  test('preferences persist privacy choices', () async {
    await database.setPreference('balances_visible', 'false');
    expect(await database.preference('balances_visible'), 'false');
  });
}
