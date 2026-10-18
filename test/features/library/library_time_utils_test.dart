import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/library/utils/library_time_utils.dart';

void main() {
  group('LibraryTimeUtils', () {
    test('buildTimeSlots contains all slots from 07:00 to 22:00', () {
      final slots = LibraryTimeUtils.buildTimeSlots();
      expect(slots.first, '07:00');
      expect(slots.last, '22:00');
      expect(slots.contains('12:00'), isTrue);
      expect(slots.contains('12:30'), isTrue);
    });

    test('availableReserveDays only returns today before 22:00 (UTC+8)', () {
      // 2026-09-02 21:59:59 Beijing time
      final before22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 21, 59, 59);
      final days = LibraryTimeUtils.availableReserveDays(now: before22);

      expect(days, ['2026-09-02']);
    });

    test('availableReserveDays returns today and tomorrow at or after 22:00 (UTC+8)', () {
      // 2026-09-02 22:00:00 Beijing time
      final at22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 22, 0, 0);
      final daysAt22 = LibraryTimeUtils.availableReserveDays(now: at22);
      expect(daysAt22, ['2026-09-02', '2026-09-03']);

      // 2026-09-02 23:30:00 Beijing time
      final after22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 23, 30, 0);
      final daysAfter22 = LibraryTimeUtils.availableReserveDays(now: after22);
      expect(daysAfter22, ['2026-09-02', '2026-09-03']);
    });

    test('availableReserveDays rolls over at midnight (UTC+8)', () {
      // 2026-09-03 00:00:01 Beijing time
      final afterMidnight = LibraryTimeUtils.beijingDateTime(2026, 9, 3, 0, 0, 1);
      final days = LibraryTimeUtils.availableReserveDays(now: afterMidnight);
      expect(days, ['2026-09-03']);
    });

    test('availableReserveDays handles cross-timezone UTC offsets correctly', () {
      // Suppose local device is UTC+0 at 13:59:59 UTC -> Beijing time is 21:59:59 (before 22:00)
      final utcBefore22 = DateTime.utc(2026, 9, 2, 13, 59, 59);
      expect(LibraryTimeUtils.availableReserveDays(now: utcBefore22), ['2026-09-02']);

      // 14:00:00 UTC -> Beijing time is 22:00:00 (at 22:00)
      final utcAt22 = DateTime.utc(2026, 9, 2, 14, 0, 0);
      expect(LibraryTimeUtils.availableReserveDays(now: utcAt22), ['2026-09-02', '2026-09-03']);
    });

    test('formatDayLabel formats today, tomorrow, and weekday correctly based on Beijing time', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 12, 0);

      expect(LibraryTimeUtils.formatDayLabel('2026-09-02', now: now), '今天 (9月2日)');
      expect(LibraryTimeUtils.formatDayLabel('2026-09-03', now: now), '明天 (9月3日)');
      expect(LibraryTimeUtils.formatDayLabel('2026-09-04', now: now), '周五 (9月4日)');
    });

    test('candidateEndSlots filters out past times when day is today', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 18, 36, 34);
      const today = '2026-09-02';

      final startSlots =
          LibraryTimeUtils.availableStartSlots(today, now: now);
      final endSlots =
          LibraryTimeUtils.candidateEndSlots(today, now: now);

      // Start slots should not include anything <= 18:36
      expect(startSlots.contains('07:00'), isFalse);
      expect(startSlots.contains('18:30'), isFalse);
      expect(startSlots.first, '19:00');
      expect(startSlots.last, '21:30');

      // Candidate end slots should not include anything <= 18:36
      expect(endSlots.contains('07:00'), isFalse);
      expect(endSlots.contains('18:30'), isFalse);
      expect(endSlots.first, '19:00');
      expect(endSlots.last, '22:00');
    });

    test('candidateEndSlots keeps all slots for future days', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 18, 36, 34);
      const tomorrow = '2026-09-03';

      final startSlots =
          LibraryTimeUtils.availableStartSlots(tomorrow, now: now);
      final endSlots =
          LibraryTimeUtils.candidateEndSlots(tomorrow, now: now);

      expect(startSlots.first, '07:00');
      expect(startSlots.last, '21:30');
      expect(endSlots.first, '07:00');
      expect(endSlots.last, '22:00');
    });

    test('isValidRange validates start and end times properly', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 10, 0);
      const today = '2026-09-02';
      const tomorrow = '2026-09-03';

      // Valid range in future
      expect(LibraryTimeUtils.isValidRange(today, '11:00', '13:00', now: now), isTrue);
      // Invalid: start time is in past
      expect(LibraryTimeUtils.isValidRange(today, '09:00', '11:00', now: now), isFalse);
      // Invalid: end time before start time
      expect(LibraryTimeUtils.isValidRange(today, '13:00', '11:00', now: now), isFalse);
      // Valid on tomorrow
      expect(LibraryTimeUtils.isValidRange(tomorrow, '08:00', '12:00', now: now), isTrue);
    });

    test('initialReserveDay recommends today when slots are available, tomorrow when after 22:00 or slots exhausted', () {
      // 1. Daytime before 22:00 with available slots -> today
      final daytime = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 14, 0);
      expect(LibraryTimeUtils.initialReserveDay(now: daytime), equals('2026-09-02'));

      // 2. Evening before 22:00 but all today slots exhausted (e.g. 21:35, since last start slot is 21:30) -> tomorrow
      final eveningNoSlots = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 21, 35);
      expect(LibraryTimeUtils.initialReserveDay(now: eveningNoSlots), equals('2026-09-03'));

      // 3. At or after 22:00 -> tomorrow
      final at22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 22, 0);
      expect(LibraryTimeUtils.initialReserveDay(now: at22), equals('2026-09-03'));

      final after22 = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 23, 15);
      expect(LibraryTimeUtils.initialReserveDay(now: after22), equals('2026-09-03'));
    });

    test('defaultStartTime selects first available slot for today and 08:00 for future days', () {
      final now = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 10, 15);
      const today = '2026-09-02';
      const tomorrow = '2026-09-03';

      // For today, next available slot after 10:15 is 10:30
      expect(LibraryTimeUtils.defaultStartTime(today, now: now), equals('10:30'));

      // For tomorrow, standard default is 08:00
      expect(LibraryTimeUtils.defaultStartTime(tomorrow, now: now), equals('08:00'));

      // When today has no available slots (e.g. 21:45) -> null
      final lateNow = LibraryTimeUtils.beijingDateTime(2026, 9, 2, 21, 45);
      expect(LibraryTimeUtils.defaultStartTime(today, now: lateNow), isNull);
    });

    test('defaultEndTime selects slot 2 hours later capped at closingHour', () {
      // 08:00 + 2h -> 10:00
      expect(LibraryTimeUtils.defaultEndTime('08:00'), equals('10:00'));
      // 20:30 + 2h -> caps at 22:00
      expect(LibraryTimeUtils.defaultEndTime('20:30'), equals('22:00'));
      // 21:30 -> caps at 22:00
      expect(LibraryTimeUtils.defaultEndTime('21:30'), equals('22:00'));
      // 22:00 (closing hour, cannot be start time) -> null
      expect(LibraryTimeUtils.defaultEndTime('22:00'), isNull);
      // Invalid start time -> null
      expect(LibraryTimeUtils.defaultEndTime('99:99'), isNull);
    });

    test('availableEndSlots returns all subsequent slots up to 22:00', () {
      final endSlotsFrom21 = LibraryTimeUtils.availableEndSlots('21:00');
      expect(endSlotsFrom21, equals(['21:30', '22:00']));

      final endSlotsFromClosing = LibraryTimeUtils.availableEndSlots('22:00');
      expect(endSlotsFromClosing, isEmpty);

      final endSlotsInvalid = LibraryTimeUtils.availableEndSlots('invalid');
      expect(endSlotsInvalid, isEmpty);
    });

    test('dateTimeAt parses valid dates and rejects invalid format/values', () {
      final dt = LibraryTimeUtils.dateTimeAt('2026-09-02', '14:30');
      expect(dt, isNotNull);
      expect(dt!.year, equals(2026));
      expect(dt.month, equals(9));
      expect(dt.day, equals(2));
      expect(dt.hour, equals(14));
      expect(dt.minute, equals(30));

      // Malformed inputs
      expect(LibraryTimeUtils.dateTimeAt('2026-09', '14:30'), isNull);
      expect(LibraryTimeUtils.dateTimeAt('2026-09-02', '14'), isNull);
      expect(LibraryTimeUtils.dateTimeAt('bad-date', '14:30'), isNull);
      // Calendar overflow (February 31)
      expect(LibraryTimeUtils.dateTimeAt('2026-02-31', '12:00'), isNull);
    });
  });
}
