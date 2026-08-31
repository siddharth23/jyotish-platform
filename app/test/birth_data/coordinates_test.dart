import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/features/birth_data/coordinates.dart';

double? degreesOf(CoordinateResult r) =>
    r is CoordinateParsed ? r.degrees : null;

CoordinateRejection? rejectionOf(CoordinateResult r) =>
    r is CoordinateRejected ? r.reason : null;

void main() {
  group('US-021 AC4 — decimal degrees', () {
    test('a plain decimal parses', () {
      expect(degreesOf(parseCoordinate('48.1374', CoordinateAxis.latitude)),
          closeTo(48.1374, 1e-9));
    });

    test('a German decimal comma parses', () {
      // A German keyboard and a German locale both produce this.
      expect(degreesOf(parseCoordinate('48,1374', CoordinateAxis.latitude)),
          closeTo(48.1374, 1e-9));
    });

    test('a negative value parses', () {
      expect(degreesOf(parseCoordinate('-33.8688', CoordinateAxis.latitude)),
          closeTo(-33.8688, 1e-9));
    });

    test('hemisphere letters set the sign', () {
      expect(degreesOf(parseCoordinate('33.8688 S', CoordinateAxis.latitude)),
          closeTo(-33.8688, 1e-9));
      expect(degreesOf(parseCoordinate('73.9 W', CoordinateAxis.longitude)),
          closeTo(-73.9, 1e-9));
    });

    test('O means Ost, not west', () {
      // A German atlas writes east as O. Reading it as the English "west"
      // would put the birthplace on the other side of the planet, silently.
      expect(degreesOf(parseCoordinate('11.5755 O', CoordinateAxis.longitude)),
          closeTo(11.5755, 1e-9));
    });

    test('a minus sign and a hemisphere letter together are refused', () {
      // "-48 N" is contradictory. Picking one silently would be a coin flip
      // on which hemisphere someone was born in.
      expect(rejectionOf(parseCoordinate('-48.1 N', CoordinateAxis.latitude)),
          CoordinateRejection.malformed);
    });
  });

  group('US-021 AC4 — degrees, minutes and seconds', () {
    test('a full DMS value parses', () {
      // 48° 8' 15" ≈ 48.1375
      expect(
          degreesOf(parseCoordinate('48° 8\' 15" N', CoordinateAxis.latitude)),
          closeTo(48.1375, 0.0001));
    });

    test('seconds may be omitted', () {
      expect(degreesOf(parseCoordinate('48° 8\' N', CoordinateAxis.latitude)),
          closeTo(48.1333, 0.0001));
    });

    test('bare spaces work as separators', () {
      expect(degreesOf(parseCoordinate('48 8 15 N', CoordinateAxis.latitude)),
          closeTo(48.1375, 0.0001));
    });

    test('minutes or seconds of 60 or more are refused', () {
      expect(
          rejectionOf(parseCoordinate('48° 60\' N', CoordinateAxis.latitude)),
          CoordinateRejection.outOfRange);
      expect(
          rejectionOf(
              parseCoordinate('48° 8\' 60" N', CoordinateAxis.latitude)),
          CoordinateRejection.outOfRange);
    });
  });

  group('US-021 AC4 — ranges and rubbish', () {
    test('latitude is capped at 90 and longitude at 180', () {
      expect(rejectionOf(parseCoordinate('91', CoordinateAxis.latitude)),
          CoordinateRejection.outOfRange);
      expect(degreesOf(parseCoordinate('90', CoordinateAxis.latitude)), 90);
      expect(rejectionOf(parseCoordinate('181', CoordinateAxis.longitude)),
          CoordinateRejection.outOfRange);
      expect(degreesOf(parseCoordinate('180', CoordinateAxis.longitude)), 180);
    });

    test('a latitude of 100 is refused even though it is a valid longitude',
        () {
      expect(rejectionOf(parseCoordinate('100', CoordinateAxis.latitude)),
          CoordinateRejection.outOfRange);
      expect(degreesOf(parseCoordinate('100', CoordinateAxis.longitude)), 100);
    });

    test('empty is its own rejection', () {
      expect(rejectionOf(parseCoordinate('  ', CoordinateAxis.latitude)),
          CoordinateRejection.empty);
    });

    test('text is refused', () {
      expect(rejectionOf(parseCoordinate('München', CoordinateAxis.latitude)),
          CoordinateRejection.malformed);
      expect(rejectionOf(parseCoordinate('48.1 X', CoordinateAxis.latitude)),
          CoordinateRejection.malformed);
    });

    test('the result is rounded to four decimals, like the gazetteer', () {
      final r =
          degreesOf(parseCoordinate('48.13748888', CoordinateAxis.latitude));
      expect(r, closeTo(48.1375, 1e-9));
    });
  });
}
