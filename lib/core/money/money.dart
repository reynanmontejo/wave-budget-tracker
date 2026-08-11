import 'package:intl/intl.dart';

final class Money {
  const Money(this.minorUnits, {this.currencyCode = 'PHP'});

  final int minorUnits;
  final String currencyCode;

  double get majorUnits => minorUnits / 100;

  String format({String locale = 'en_PH'}) {
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: currencyCode,
      decimalDigits: 2,
    ).format(majorUnits);
  }

  static int? parseMajorUnits(String input) {
    final normalized = input.replaceAll(',', '').trim();
    final value = num.tryParse(normalized);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }
}
