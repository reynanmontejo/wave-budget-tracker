import 'database/app_database.dart';
import 'database/seed_data.dart';
import 'management_repository.dart';

final class OnboardingRepository {
  OnboardingRepository(this.database);
  static const completionKey = 'onboarding_completed';
  final AppDatabase database;

  Future<bool> isComplete() async =>
      await database.preference(completionKey) == 'true';

  Future<void> complete({
    required String accountName,
    required String accountType,
    required int openingBalanceMinor,
  }) async {
    await database.transaction(() async {
      await ManagementRepository(database).createAccount(
        name: accountName,
        typeName: accountType,
        openingBalanceMinor: openingBalanceMinor,
      );
      await seedDatabase(database);
      await database.setPreference(completionKey, 'true');
    });
  }
}
