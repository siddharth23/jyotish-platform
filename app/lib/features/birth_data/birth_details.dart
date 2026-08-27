/// Birth date and time as the user enters them (US-020).
///
/// ## Why this parses by hand instead of using DateTime
///
/// `DateTime(2000, 4, 31)` does not throw. It returns the 1st of May. Every
/// date library in wide use rolls over silently, which means a typo in the day
/// produces a valid-looking chart for the wrong date and nothing anywhere says
/// so. For a €11 report keyed to a birth moment, a silent off-by-one-day is
/// worse than a rejection, so [parseGermanDate] checks that the parts it was
/// given survive the round trip.
///
/// ## Why the format is fixed rather than locale-guessed
///
/// `01.02.2000` is 1 February in Germany and 2 January nowhere that writes it
/// with dots — but `01/02/2000` is genuinely ambiguous, and a parser that
/// accepts both separators will eventually be handed one by a user who pasted
/// it. AC1 says DD.MM.YYYY, so dots only, and the field says so in its hint.
///
/// ## Time is 24-hour, and that is a correctness requirement
///
/// AC1 says HH:mm. There is no am/pm in German usage, and accepting a bare
/// `7:30` from someone who meant half past seven in the evening moves the
/// ascendant by roughly half the zodiac. The field takes 00:00–23:59 and
/// nothing else.
///
/// LICENSING: no engine code. See docs/AGPL-BOUNDARY.md.
library;

/// The earliest year accepted. AC3.
///
/// Swiss Ephemeris reaches far further back, so this is not an engine limit.
/// It is a data-quality one: a birth before 1800 is a transcription error or a
/// genealogy project, and in either case the timezone history needed to place
/// the moment does not exist — civil time in the German states was local mean
/// solar time until the 1890s, varying by town.
const int earliestBirthYear = 1800;

/// Whether the birth time is known to the minute.
enum BirthTimePrecision {
  /// The user gave a clock time. A full chart can be computed.
  exact,

  /// AC2. The user does not know it, so the chart falls back to a solar chart.
  unknown,
}

/// Why an entered value was rejected.
///
/// A code rather than a message: the copy is localised, and the reason has to
/// survive being tested without a `BuildContext`.
enum BirthFieldRejection {
  empty,

  /// Not DD.MM.YYYY, or not HH:mm.
  malformed,

  /// The parts parsed but do not name a real day — 31.04, 29.02 in a common year.
  notACalendarDate,

  /// AC3.
  inTheFuture,

  /// AC3.
  tooEarly,

  /// Outside 00:00–23:59.
  outOfRange,
}

sealed class ParseResult<T> {
  const ParseResult();
}

class ParseSuccess<T> extends ParseResult<T> {
  const ParseSuccess(this.value);
  final T value;
}

class ParseFailure<T> extends ParseResult<T> {
  const ParseFailure(this.reason);
  final BirthFieldRejection reason;
}

/// A calendar date, with no time and no zone.
///
/// Deliberately not a [DateTime]. A `DateTime` is a moment, and a birth date
/// on its own is not one — turning it into a moment requires the birthplace
/// and the historical timezone rules for that place on that day, which is
/// US-022's job. Storing a `DateTime` here would invite someone to call
/// `.toUtc()` on it and shift the date across midnight.
class BirthDate {
  const BirthDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is BirthDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => format();

  /// DD.MM.YYYY, zero-padded. The form AC1 requires.
  String format() =>
      '${_pad(day)}.${_pad(month)}.${year.toString().padLeft(4, '0')}';
}

/// A wall-clock time of day. Not a moment, for the same reason as [BirthDate].
class BirthTime {
  const BirthTime(this.hour, this.minute);

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is BirthTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => format();

  /// HH:mm, 24-hour, zero-padded.
  String format() => '${_pad(hour)}:${_pad(minute)}';
}

String _pad(int value) => value.toString().padLeft(2, '0');

/// Parses DD.MM.YYYY strictly.
///
/// [today] is the user's local date, injected so "no future dates" is testable
/// and so the boundary is the user's midnight rather than UTC's — someone born
/// today in Berlin at 01:00 would otherwise be told their birth date is in the
/// future for an hour every night.
ParseResult<BirthDate> parseGermanDate(String input,
    {required BirthDate today}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const ParseFailure(BirthFieldRejection.empty);

  final match = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(trimmed);
  if (match == null) return const ParseFailure(BirthFieldRejection.malformed);

  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);

  if (month < 1 || month > 12 || day < 1) {
    return const ParseFailure(BirthFieldRejection.notACalendarDate);
  }

  // The round trip is the check. DateTime rolls 31.04 over to 01.05 without
  // complaint, so the only reliable test is whether what came back is what
  // went in. Leap years come out of this for free, including 1900 (not a leap
  // year) and 2000 (one), which a hand-written rule usually gets wrong.
  final probe = DateTime(year, month, day);
  if (probe.year != year || probe.month != month || probe.day != day) {
    return const ParseFailure(BirthFieldRejection.notACalendarDate);
  }

  if (year < earliestBirthYear) {
    return const ParseFailure(BirthFieldRejection.tooEarly);
  }
  if (_isAfter(BirthDate(year, month, day), today)) {
    return const ParseFailure(BirthFieldRejection.inTheFuture);
  }

  return ParseSuccess(BirthDate(year, month, day));
}

/// Parses HH:mm, 24-hour.
///
/// `24:00` is rejected even though ISO 8601 permits it as end-of-day: as a
/// birth time it means midnight, and accepting it would put the birth on a day
/// the user did not name.
ParseResult<BirthTime> parseTime(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const ParseFailure(BirthFieldRejection.empty);

  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
  if (match == null) return const ParseFailure(BirthFieldRejection.malformed);

  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) {
    return const ParseFailure(BirthFieldRejection.outOfRange);
  }
  return ParseSuccess(BirthTime(hour, minute));
}

bool _isAfter(BirthDate a, BirthDate b) {
  if (a.year != b.year) return a.year > b.year;
  if (a.month != b.month) return a.month > b.month;
  return a.day > b.day;
}

/// What the user entered, once both fields are valid.
class BirthDetails {
  /// [time] is null when the user chose "time unknown" — see [precision].
  const BirthDetails({required this.date, required this.time});

  final BirthDate date;

  /// Null when the user chose "time unknown" (AC2).
  final BirthTime? time;

  BirthTimePrecision get precision =>
      time == null ? BirthTimePrecision.unknown : BirthTimePrecision.exact;

  /// Whether the chart must fall back to a solar chart. AC2.
  ///
  /// The fallback is not a smaller version of the same chart. Without a time
  /// there is no ascendant, so there are no houses, and every reading that
  /// depends on a house — which is most of them, including the career analysis
  /// this app sells — is unavailable or approximate. The caveat the UI shows
  /// says that, rather than implying a slightly less precise result.
  bool get needsSolarChartFallback => precision == BirthTimePrecision.unknown;
}
