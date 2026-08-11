import 'package:flutter_test/flutter_test.dart';
import 'package:wave/core/money/money.dart';

void main() {
  test('parses decimal major units into integer minor units', () {
    expect(Money.parseMajorUnits('1,250.50'), 125050);
    expect(Money.parseMajorUnits('0.01'), 1);
  });

  test('rejects invalid and negative amounts', () {
    expect(Money.parseMajorUnits('hello'), isNull);
    expect(Money.parseMajorUnits('-1'), isNull);
  });
}
