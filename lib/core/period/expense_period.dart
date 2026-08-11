enum ExpensePeriodKind { day, week, month, year, custom }

final class ExpensePeriod {
  const ExpensePeriod._({
    required this.kind,
    required this.startInclusive,
    required this.endExclusive,
    required this.label,
  });

  factory ExpensePeriod.day(DateTime day) {
    final start = _dateOnly(day);
    return ExpensePeriod._(
      kind: ExpensePeriodKind.day,
      startInclusive: start,
      endExclusive: start.add(const Duration(days: 1)),
      label: _isSameDate(start, DateTime.now()) ? 'Today' : 'Day',
    );
  }

  factory ExpensePeriod.week(DateTime day) {
    final date = _dateOnly(day);
    final start = date.subtract(Duration(days: date.weekday - DateTime.monday));
    return ExpensePeriod._(
      kind: ExpensePeriodKind.week,
      startInclusive: start,
      endExclusive: start.add(const Duration(days: 7)),
      label: 'Week',
    );
  }

  factory ExpensePeriod.month(DateTime day) {
    final start = DateTime(day.year, day.month);
    return ExpensePeriod._(
      kind: ExpensePeriodKind.month,
      startInclusive: start,
      endExclusive: DateTime(day.year, day.month + 1),
      label: 'Month',
    );
  }

  factory ExpensePeriod.year(DateTime day) {
    final start = DateTime(day.year);
    return ExpensePeriod._(
      kind: ExpensePeriodKind.year,
      startInclusive: start,
      endExclusive: DateTime(day.year + 1),
      label: 'Year',
    );
  }

  factory ExpensePeriod.custom(DateTime start, DateTime inclusiveEnd) {
    final normalizedStart = _dateOnly(start);
    final normalizedEnd = _dateOnly(inclusiveEnd);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError('The end date must not be before the start date.');
    }
    return ExpensePeriod._(
      kind: ExpensePeriodKind.custom,
      startInclusive: normalizedStart,
      endExclusive: normalizedEnd.add(const Duration(days: 1)),
      label: 'Custom',
    );
  }

  final ExpensePeriodKind kind;
  final DateTime startInclusive;
  final DateTime endExclusive;
  final String label;

  bool contains(DateTime value) =>
      !value.isBefore(startInclusive) && value.isBefore(endExclusive);

  ExpensePeriod get previous {
    final duration = endExclusive.difference(startInclusive);
    final end = startInclusive;
    final start = end.subtract(duration);
    return ExpensePeriod._(
      kind: kind,
      startInclusive: start,
      endExclusive: end,
      label: 'Previous $label',
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
