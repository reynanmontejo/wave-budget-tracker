import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/period/expense_period.dart';

void main() {
  group('ExpensePeriod', () {
    test('week runs from Monday through Sunday', () {
      final period = ExpensePeriod.week(DateTime(2026, 8, 5));
      expect(period.startInclusive, DateTime(2026, 8, 3));
      expect(period.endExclusive, DateTime(2026, 8, 10));
    });

    test('month handles leap years', () {
      final period = ExpensePeriod.month(DateTime(2024, 2, 15));
      expect(period.startInclusive, DateTime(2024, 2));
      expect(period.endExclusive, DateTime(2024, 3));
      expect(period.contains(DateTime(2024, 2, 29, 23, 59)), isTrue);
      expect(period.contains(DateTime(2024, 3)), isFalse);
    });

    test('custom range includes the full final day', () {
      final period = ExpensePeriod.custom(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 10),
      );
      expect(period.contains(DateTime(2026, 8, 10, 23, 59, 59)), isTrue);
      expect(period.contains(DateTime(2026, 8, 11)), isFalse);
    });

    test('custom range rejects reversed dates', () {
      expect(
        () => ExpensePeriod.custom(DateTime(2026, 8, 10), DateTime(2026, 8, 1)),
        throwsArgumentError,
      );
    });
  });
}
