import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/features/birth_data/birth_details.dart';

/// Synthetic throughout: CLAUDE.md forbids real birth data in fixtures.
const today = BirthDate(2026, 8, 23);

BirthFieldRejection? rejectionOf<T>(ParseResult<T> result) =>
    result is ParseFailure<T> ? result.reason : null;

T valueOf<T>(ParseResult<T> result) => (result as ParseSuccess<T>).value;

void main() {
  group('US-020 AC1 — DD.MM.YYYY', () {
    test('a well-formed German date parses', () {
      final result = parseGermanDate('17.05.1990', today: today);
      expect(valueOf(result), const BirthDate(1990, 5, 17));
    });

    test('single-digit day and month are accepted', () {
      // People type 1.2.1990. Rejecting it would be pedantry, and the field
      // reformats to the padded form on submit.
      expect(valueOf(parseGermanDate('1.2.1990', today: today)),
          const BirthDate(1990, 2, 1));
    });

    test('it round-trips to the padded German form', () {
      expect(const BirthDate(1990, 2, 1).format(), '01.02.1990');
    });

    test('slashes are rejected, because 01/02 is genuinely ambiguous', () {
      expect(rejectionOf(parseGermanDate('17/05/1990', today: today)),
          BirthFieldRejection.malformed);
    });

    test('ISO order is rejected', () {
      expect(rejectionOf(parseGermanDate('1990-05-17', today: today)),
          BirthFieldRejection.malformed);
    });

    test('a two-digit year is rejected rather than guessed', () {
      // "90" could be 1990 or 2090. Guessing gets it wrong for anyone born
      // after 2000 and there is no way for them to tell.
      expect(rejectionOf(parseGermanDate('17.05.90', today: today)),
          BirthFieldRejection.malformed);
    });

    test('empty is its own rejection, not a malformed one', () {
      expect(rejectionOf(parseGermanDate('   ', today: today)),
          BirthFieldRejection.empty);
    });

    test('surrounding whitespace is tolerated', () {
      expect(valueOf(parseGermanDate('  17.05.1990  ', today: today)),
          const BirthDate(1990, 5, 17));
    });
  });

  group('US-020 AC1 — a date that does not exist is caught, not rolled over',
      () {
    test('31 April is rejected, not silently turned into 1 May', () {
      // DateTime(2000, 4, 31) returns 1 May without complaint. That would
      // produce a valid-looking chart for a day the user did not name.
      final result = parseGermanDate('31.04.2000', today: today);
      expect(rejectionOf(result), BirthFieldRejection.notACalendarDate);
    });

    test('29 February in a common year is rejected', () {
      expect(rejectionOf(parseGermanDate('29.02.1999', today: today)),
          BirthFieldRejection.notACalendarDate);
    });

    test('29 February in a leap year is accepted', () {
      expect(valueOf(parseGermanDate('29.02.2000', today: today)),
          const BirthDate(2000, 2, 29));
    });

    test('1900 is not a leap year and 2000 is', () {
      // The century rule, which hand-written leap checks usually get wrong.
      expect(rejectionOf(parseGermanDate('29.02.1900', today: today)),
          BirthFieldRejection.notACalendarDate);
      expect(valueOf(parseGermanDate('29.02.2000', today: today)),
          const BirthDate(2000, 2, 29));
    });

    test('month 13 and day 0 are rejected', () {
      expect(rejectionOf(parseGermanDate('01.13.1990', today: today)),
          BirthFieldRejection.notACalendarDate);
      expect(rejectionOf(parseGermanDate('00.05.1990', today: today)),
          BirthFieldRejection.notACalendarDate);
    });
  });

  group('US-020 AC3 — no future dates, 1800 or later', () {
    test('today is allowed', () {
      expect(valueOf(parseGermanDate('23.08.2026', today: today)), today);
    });

    test('tomorrow is rejected', () {
      expect(rejectionOf(parseGermanDate('24.08.2026', today: today)),
          BirthFieldRejection.inTheFuture);
    });

    test('the boundary is the day, not the month or year', () {
      expect(rejectionOf(parseGermanDate('01.09.2026', today: today)),
          BirthFieldRejection.inTheFuture);
      expect(rejectionOf(parseGermanDate('01.01.2027', today: today)),
          BirthFieldRejection.inTheFuture);
      expect(valueOf(parseGermanDate('31.07.2026', today: today)),
          const BirthDate(2026, 7, 31));
    });

    test('1800 is accepted and 1799 is not', () {
      expect(valueOf(parseGermanDate('01.01.1800', today: today)),
          const BirthDate(1800, 1, 1));
      expect(rejectionOf(parseGermanDate('31.12.1799', today: today)),
          BirthFieldRejection.tooEarly);
    });

    test('the earliest year is 1800', () {
      expect(earliestBirthYear, 1800);
    });

    test('an impossible date before 1800 reports the calendar problem first',
        () {
      // Both are wrong; the one the user can act on is the day.
      expect(rejectionOf(parseGermanDate('31.02.1750', today: today)),
          BirthFieldRejection.notACalendarDate);
    });
  });

  group('US-020 AC1 — 24-hour HH:mm', () {
    test('a well-formed time parses', () {
      expect(valueOf(parseTime('07:30')), const BirthTime(7, 30));
    });

    test('a single-digit hour is accepted and pads on output', () {
      expect(valueOf(parseTime('7:30')), const BirthTime(7, 30));
      expect(const BirthTime(7, 30).format(), '07:30');
    });

    test('the full 24-hour range is accepted', () {
      expect(valueOf(parseTime('00:00')), const BirthTime(0, 0));
      expect(valueOf(parseTime('23:59')), const BirthTime(23, 59));
    });

    test('24:00 is rejected', () {
      // ISO 8601 allows it as end-of-day, but as a birth time it means
      // midnight, which belongs to a different date than the one entered.
      expect(rejectionOf(parseTime('24:00')), BirthFieldRejection.outOfRange);
    });

    test('minute 60 is rejected', () {
      expect(rejectionOf(parseTime('12:60')), BirthFieldRejection.outOfRange);
    });

    test('am/pm is rejected rather than interpreted', () {
      // Reading "7:30 pm" as 07:30 moves the ascendant by roughly half the
      // zodiac, and nothing downstream would flag it.
      expect(rejectionOf(parseTime('7:30 pm')), BirthFieldRejection.malformed);
      expect(rejectionOf(parseTime('07:30PM')), BirthFieldRejection.malformed);
    });

    test('a dot separator is rejected', () {
      expect(rejectionOf(parseTime('07.30')), BirthFieldRejection.malformed);
    });

    test('a bare hour is rejected', () {
      expect(rejectionOf(parseTime('7')), BirthFieldRejection.malformed);
    });

    test('a single-digit minute is rejected rather than guessed', () {
      // "7:3" is 07:03 or 07:30 depending on who you ask.
      expect(rejectionOf(parseTime('7:3')), BirthFieldRejection.malformed);
    });
  });

  group('US-020 AC2 — time unknown means a solar chart', () {
    test('a known time needs no fallback', () {
      const details = BirthDetails(
        date: BirthDate(1990, 5, 17),
        time: BirthTime(7, 30),
      );
      expect(details.precision, BirthTimePrecision.exact);
      expect(details.needsSolarChartFallback, isFalse);
    });

    test('a null time is unknown precision and triggers the fallback', () {
      const details = BirthDetails(date: BirthDate(1990, 5, 17), time: null);
      expect(details.precision, BirthTimePrecision.unknown);
      expect(details.needsSolarChartFallback, isTrue);
    });
  });
}
