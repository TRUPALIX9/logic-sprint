import 'package:flutter_test/flutter_test.dart';
import 'package:logic_sprint/core/format.dart';

void main() {
  final now = DateTime(2026, 9, 13, 15);

  test('formatClock', () {
    expect(formatClock(DateTime(2026, 9, 13, 9, 14)), '9:14 AM');
    expect(formatClock(DateTime(2026, 9, 13, 0, 5)), '12:05 AM');
    expect(formatClock(DateTime(2026, 9, 13, 12)), '12:00 PM');
    expect(formatClock(DateTime(2026, 9, 13, 20, 2)), '8:02 PM');
  });

  test('formatDayTime: today, yesterday, a date', () {
    expect(
      formatDayTime(DateTime(2026, 9, 13, 9, 14), now: now),
      'today, 9:14 AM',
    );
    expect(
      formatDayTime(DateTime(2026, 9, 12, 20, 2), now: now),
      'yesterday, 8:02 PM',
    );
    expect(
      formatDayTime(DateTime(2026, 9, 9, 20, 2), now: now),
      'Sep 9, 8:02 PM',
    );
    expect(
      formatDayTime(DateTime(2025, 12, 31, 23), now: now),
      'Dec 31, 2025, 11:00 PM',
    );
  });

  test('formatWhen goes by calendar day, not 24 h', () {
    expect(formatWhen(DateTime(2026, 9, 13, 13), now: now), '2 h ago');
    expect(formatWhen(DateTime(2026, 9, 12, 23), now: now), 'yesterday');
    expect(formatWhen(DateTime(2026, 9, 9, 8), now: now), 'Sep 9');
  });

  test('formatSince', () {
    expect(formatSince(DateTime(2026, 9, 13, 9, 14), now: now), '9:14 AM');
    expect(formatSince(DateTime(2026, 9, 12, 8), now: now), 'yesterday');
    expect(formatSince(DateTime(2026, 9, 10, 8), now: now), 'Sep 10');
  });

  test('calendarDaysBetween', () {
    expect(
      calendarDaysBetween(DateTime(2026, 9, 12, 23, 59), DateTime(2026, 9, 13)),
      1,
    );
    expect(calendarDaysBetween(DateTime(2026, 9, 13, 1), now), 0);
    expect(calendarDaysBetween(DateTime(2026, 8, 31), now), 13);
  });
}
