import 'package:bratnava_fc_app/core/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseApiDate', () {
    test('keeps timezone-less values as local wall time', () {
      final parsed = parseApiDate('2026-07-14T21:00:00');

      expect(parsed.year, 2026);
      expect(parsed.month, 7);
      expect(parsed.day, 14);
      expect(parsed.hour, 21);
      expect(parsed.minute, 0);
    });

    test('converts UTC values to Sao Paulo wall time', () {
      final parsed = parseApiDate('2026-07-15T00:00:00Z');

      expect(parsed.year, 2026);
      expect(parsed.month, 7);
      expect(parsed.day, 14);
      expect(parsed.hour, 21);
      expect(parsed.minute, 0);
    });
  });

  group('parseApiInstantOrNull', () {
    test('keeps timezone-less action times as local wall time', () {
      final parsed = parseApiInstantOrNull('2026-07-14T23:02:00');

      expect(parsed?.hour, 23);
      expect(parsed?.minute, 2);
    });

    test('converts UTC action times to Sao Paulo wall time', () {
      final parsed = parseApiInstantOrNull('2026-07-15T02:02:00Z');

      expect(parsed?.year, 2026);
      expect(parsed?.month, 7);
      expect(parsed?.day, 14);
      expect(parsed?.hour, 23);
      expect(parsed?.minute, 2);
    });
  });
}
