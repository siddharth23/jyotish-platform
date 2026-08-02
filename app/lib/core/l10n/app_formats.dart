import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Locale-aware formatting for dates, times, numbers and money.
///
/// Never format by string interpolation. `'$day.$month.$year'` produces German
/// order in every locale, and `'€$amount'` produces `€11.00` where German writes
/// `11,00 €` — symbol after the amount, comma decimal, non-breaking space. Both
/// mistakes look correct to an English-speaking developer and wrong to every
/// German customer, on the screen where they are deciding whether to pay.
abstract final class AppFormats {
  /// 17.05.1990 in German, 17/05/1990 in en-GB.
  ///
  /// The pattern is explicit rather than `DateFormat.yMd`, which yields the
  /// locale's idiomatic short form — `17.5.1990` for German, dropping the
  /// leading zero. US-004 and the backlog both specify DD.MM.YYYY, and a
  /// zero-padded, fixed-width date is what German forms use and what keeps a
  /// column of birth dates aligned.
  ///
  /// Only the two shipped locales are listed. Adding a third means adding its
  /// pattern here; the fallback is the German one, since German is the template
  /// locale.
  static String date(BuildContext context, DateTime value) {
    final pattern = switch (Localizations.localeOf(context).languageCode) {
      'en' => 'dd/MM/yyyy',
      _ => 'dd.MM.yyyy',
    };
    return DateFormat(pattern, _tag(context)).format(value);
  }

  /// 17. Mai 1990 in German, 17 May 1990 in en-GB.
  static String longDate(BuildContext context, DateTime value) =>
      DateFormat.yMMMMd(_tag(context)).format(value);

  /// Time of day.
  ///
  /// Always 24-hour, in both locales. German uses it and, more importantly, a
  /// birth time of `08:30` must never be ambiguous about am/pm — an error of
  /// twelve hours moves the ascendant by roughly six signs.
  static String time(BuildContext context, DateTime value) =>
      DateFormat.Hm(_tag(context)).format(value);

  /// Date and time together.
  static String dateTime(BuildContext context, DateTime value) =>
      '${date(context, value)}, ${time(context, value)}';

  /// A decimal number: 1.234,5 in German, 1,234.5 in en-GB.
  static String number(BuildContext context, num value, {int decimals = 1}) =>
      NumberFormat.decimalPatternDigits(
        locale: _tag(context),
        decimalDigits: decimals,
      ).format(value);

  /// A euro amount: 11,00 € in German, €11.00 in en-GB.
  ///
  /// Both locales are given an explicit EUR symbol. Left to its own devices
  /// en-GB would format euros with a pound sign's conventions or fall back to
  /// the ISO code, and the price shown at checkout has to be exactly the price
  /// charged.
  static String euro(BuildContext context, num amount) => NumberFormat.currency(
        locale: _tag(context),
        symbol: '€',
        decimalDigits: 2,
      ).format(amount);

  /// Degrees, minutes and seconds of arc: 5°12′34″.
  ///
  /// Not localised. The symbols are astronomical notation, identical in every
  /// language, and the digits are already tabular in [AppTypography.numeric].
  static String arc(double degrees) {
    final total = degrees.abs();
    final d = total.floor();
    final minutesTotal = (total - d) * 60;
    final m = minutesTotal.floor();
    final s = ((minutesTotal - m) * 60).round();
    // Rounding seconds to 60 must carry, or the output reads 5°12′60″.
    final (dd, mm, ss) = switch ((d, m, s)) {
      (final x, final y, 60) when y == 59 => (x + 1, 0, 0),
      (final x, final y, 60) => (x, y + 1, 0),
      final other => other,
    };
    final sign = degrees.isNegative ? '-' : '';
    return '$sign$dd°${mm.toString().padLeft(2, '0')}′'
        '${ss.toString().padLeft(2, '0')}″';
  }

  static String _tag(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();
}
