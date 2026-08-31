/// Manual coordinate entry (US-021 AC4).
///
/// The gazetteer covers places above 5,000 people. Someone born in a village,
/// at home, or in a town whose name has changed since will not find themselves
/// in it, and a birthplace field with no way out is a dead end in the only
/// flow that matters. So coordinates can be typed directly.
///
/// Both notations are accepted because both are what people have to hand: a
/// phone's map app gives decimal degrees, and an atlas or a birth certificate
/// gives degrees/minutes/seconds. Refusing either would send the user off to
/// convert by hand, which is exactly where a sign error creeps in.
library;

/// Why a typed coordinate was rejected.
enum CoordinateRejection {
  empty,
  malformed,

  /// Latitude outside ±90 or longitude outside ±180.
  outOfRange,
}

sealed class CoordinateResult {
  const CoordinateResult();
}

class CoordinateParsed extends CoordinateResult {
  const CoordinateParsed(this.degrees);
  final double degrees;
}

class CoordinateRejected extends CoordinateResult {
  const CoordinateRejected(this.reason);
  final CoordinateRejection reason;
}

/// Which axis is being parsed. Only the permitted range and the hemisphere
/// letters differ.
enum CoordinateAxis {
  latitude(90, 'N', 'S'),
  longitude(180, 'E', 'W');

  const CoordinateAxis(this.limit, this.positive, this.negative);
  final double limit;
  final String positive;
  final String negative;
}

final _decimal = RegExp(r'^([+-]?\d{1,3}(?:[.,]\d+)?)\s*([NSEWOnsewo])?$');
// Triple-quoted and raw: the pattern needs a literal ' (minutes) and a
// literal " (seconds), and a raw string cannot escape its own delimiter.
final _dms = RegExp(
  r'''^(\d{1,3})\s*[°d ]\s*(\d{1,2})\s*['m ]?\s*(?:(\d{1,2}(?:[.,]\d+)?)\s*["s]?)?\s*([NSEWOnsewo])?$''',
);

/// Parses decimal degrees or degrees/minutes/seconds.
///
/// Accepts `48.1374`, `48,1374` (German decimal comma), `48.1374 N`,
/// `48° 8' 15" N`, and `48 8 15 N`.
CoordinateResult parseCoordinate(String input, CoordinateAxis axis) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const CoordinateRejected(CoordinateRejection.empty);
  }

  final decimal = _decimal.firstMatch(trimmed);
  if (decimal != null) {
    final value = double.tryParse(decimal.group(1)!.replaceAll(',', '.'));
    if (value == null) {
      return const CoordinateRejected(CoordinateRejection.malformed);
    }
    return _finish(value, decimal.group(2), axis);
  }

  final dms = _dms.firstMatch(trimmed);
  if (dms != null) {
    final degrees = double.parse(dms.group(1)!);
    final minutes = double.parse(dms.group(2)!);
    final seconds = double.parse((dms.group(3) ?? '0').replaceAll(',', '.'));
    if (minutes >= 60 || seconds >= 60) {
      return const CoordinateRejected(CoordinateRejection.outOfRange);
    }
    return _finish(degrees + minutes / 60 + seconds / 3600, dms.group(4), axis);
  }

  return const CoordinateRejected(CoordinateRejection.malformed);
}

CoordinateResult _finish(
    double magnitude, String? hemisphere, CoordinateAxis axis) {
  var value = magnitude;

  if (hemisphere != null) {
    final letter = hemisphere.toUpperCase();
    // O for Ost: a German keyboard writes east as O, and someone reading a
    // German atlas will type it. Treating it as the English "west" would put
    // the birthplace on the wrong side of the planet, silently.
    final isNegative = letter == 'S' || letter == 'W';
    final isPositive = letter == 'N' || letter == 'E' || letter == 'O';
    if (!isNegative && !isPositive) {
      return const CoordinateRejected(CoordinateRejection.malformed);
    }
    // A hemisphere letter and a minus sign together are contradictory —
    // "-48 N" means nothing. Reject rather than pick one.
    if (value < 0) {
      return const CoordinateRejected(CoordinateRejection.malformed);
    }
    if (isNegative) value = -value;
  }

  if (value.abs() > axis.limit) {
    return const CoordinateRejected(CoordinateRejection.outOfRange);
  }
  return CoordinateParsed(_roundTo4(value));
}

/// Four decimals, matching the gazetteer and AC2. More is false precision: a
/// birth record is not accurate to the metre.
double _roundTo4(double value) => (value * 10000).round() / 10000;
