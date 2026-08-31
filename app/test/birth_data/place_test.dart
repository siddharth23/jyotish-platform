import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/features/birth_data/place.dart';

/// The real bundled gazetteer.
///
/// Loaded from disk rather than through the asset bundle so this stays a plain
/// unit test. Testing against a fixture would prove the parser works and say
/// nothing about whether the data answers what people actually type — which is
/// the entire risk in this story.
final Gazetteer gazetteer = Gazetteer.parse(
  utf8.decode(
      gzip.decode(File('assets/geo/gazetteer.tsv.gz').readAsBytesSync())),
);

Place? first(String query) {
  final results = gazetteer.search(query);
  return results.isEmpty ? null : results.first;
}

void main() {
  group('US-021 AC1 — type-ahead with German exonyms', () {
    test('the three exonyms the AC names all resolve', () {
      // Mailand, Prag, Warschau — named in the acceptance criteria.
      expect(first('Mailand')?.countryCode, 'IT');
      expect(first('Prag')?.countryCode, 'CZ');
      expect(first('Warschau')?.countryCode, 'PL');
    });

    test('the German name is what comes back, not the English one', () {
      // GeoNames' primary name column says "Munich" and "Milan". Showing that
      // to a German-first audience would be wrong on the most visible field.
      expect(first('München')?.name, 'München');
      expect(first('Mailand')?.name, 'Mailand');
      expect(first('Prag')?.name, 'Prag');
      expect(first('Wien')?.name, 'Wien');
    });

    test('a prefix is enough', () {
      expect(first('Münc')?.name, 'München');
      expect(first('Warsch')?.name, 'Warschau');
    });

    test('the English name still finds the place', () {
      // Someone may well type Munich, and the app is bilingual.
      expect(first('Munich')?.name, 'München');
      expect(first('Milan')?.name, 'Mailand');
    });

    test('prefix, not substring: "ber" means Berlin', () {
      // Substring matching would bury the obvious answer under every town
      // containing the letters — Heidelberg, Bamberg, Nürnberg.
      expect(first('Berl')?.name, 'Berlin');
      expect(gazetteer.search('Berlin').first.countryCode, 'DE');
    });

    test('results are population-ordered, so the likely answer is first', () {
      // There is a Delhi in Ontario with 5,344 people.
      expect(first('Delhi')?.countryCode, 'IN');
      // And a London in Ontario, but not the one anyone means.
      expect(first('London')?.countryCode, 'GB');
    });
  });

  group('US-021 AC1 — folding, which is where German input breaks', () {
    test('umlauts can be typed, stripped, or expanded', () {
      // All three are what real people type for the same city.
      for (final query in [
        'München',
        'Munchen',
        'Muenchen',
        'munchen',
        'MUENCHEN'
      ]) {
        expect(first(query)?.name, 'München',
            reason: '"$query" should find München');
      }
    });

    test('Köln works all three ways too', () {
      for (final query in ['Köln', 'Koln', 'Koeln']) {
        expect(first(query)?.name, 'Köln', reason: '"$query" should find Köln');
      }
    });

    test('ß folds to ss', () {
      final direct = gazetteer.search('Gießen');
      final folded = gazetteer.search('Giessen');
      expect(direct, isNotEmpty);
      expect(folded.first.name, direct.first.name);
    });

    test('spaces, hyphens and apostrophes are ignored', () {
      expect(first('Baden-Baden')?.name, contains('Baden'));
      expect(first('badenbaden')?.name, contains('Baden'));
      expect(first('Frankfurt am Main')?.countryCode, 'DE');
      expect(first('frankfurtammain')?.countryCode, 'DE');
    });
  });

  group('US-021 AC3 — Indian, Turkish and German towns', () {
    test('Indian cities resolve, including historical names', () {
      // Someone born in 1970 says Bombay, not Mumbai.
      expect(first('Mumbai')?.countryCode, 'IN');
      expect(first('Bombay')?.name, 'Mumbai');
      expect(first('Kolkata')?.countryCode, 'IN');
      expect(first('Calcutta')?.countryCode, 'IN');
      expect(first('Chennai')?.countryCode, 'IN');
      expect(first('Varanasi')?.countryCode, 'IN');
    });

    test('Turkish cities resolve, dotless i and all', () {
      expect(first('Istanbul')?.countryCode, 'TR');
      expect(first('İstanbul')?.countryCode, 'TR');
      expect(first('Izmir')?.countryCode, 'TR');
      expect(first('İzmir')?.countryCode, 'TR');
      expect(first('Diyarbakır')?.countryCode, 'TR');
      expect(first('Diyarbakir')?.countryCode, 'TR');
    });

    test('smaller German towns are covered, not just the big cities', () {
      for (final town in [
        'Tübingen',
        'Lüneburg',
        'Bamberg',
        'Konstanz',
        'Görlitz'
      ]) {
        expect(first(town)?.countryCode, 'DE', reason: town);
      }
    });

    test('the gazetteer is the size the build script reports', () {
      expect(gazetteer.size, greaterThan(60000));
    });
  });

  group('US-021 AC2 — coordinates and country come back', () {
    test('four decimals, and the country code', () {
      final munich = first('München')!;
      expect(munich.countryCode, 'DE');
      expect(munich.latitude, closeTo(48.1374, 0.0001));
      expect(munich.longitude, closeTo(11.5755, 0.0001));
    });

    test('no coordinate carries more than four decimals', () {
      for (final query in ['Berlin', 'Mumbai', 'Istanbul', 'Prag']) {
        final place = first(query)!;
        for (final value in [place.latitude, place.longitude]) {
          final decimals = value.toString().split('.').last;
          expect(decimals.length, lessThanOrEqualTo(4),
              reason: '$query $value');
        }
      }
    });

    test('an IANA timezone comes with the place, for US-022', () {
      // The zone, not the offset — the offset also depends on the birth date.
      expect(first('München')?.timeZoneId, 'Europe/Berlin');
      expect(first('Mumbai')?.timeZoneId, 'Asia/Kolkata');
      expect(first('Istanbul')?.timeZoneId, 'Europe/Istanbul');
    });
  });

  group('US-021 — the search behaves under bad input', () {
    test('an empty or punctuation-only query returns nothing', () {
      expect(gazetteer.search(''), isEmpty);
      expect(gazetteer.search('   '), isEmpty);
      expect(gazetteer.search('---'), isEmpty);
    });

    test('nonsense returns nothing rather than something wrong', () {
      expect(gazetteer.search('qqzzxxjj'), isEmpty);
    });

    test('the result count is capped', () {
      expect(gazetteer.search('a', limit: 5).length, 5);
    });
  });

  group('US-021 — folding helpers', () {
    test('stripped removes diacritics', () {
      expect(foldStripped('München'), 'munchen');
      expect(foldStripped('İzmir'), 'izmir');
      expect(foldStripped('Diyarbakır'), 'diyarbakir');
    });

    test('expanded uses the German transliteration', () {
      expect(foldExpanded('München'), 'muenchen');
      expect(foldExpanded('Köln'), 'koeln');
      expect(foldExpanded('Gießen'), 'giessen');
    });

    test('both drop punctuation and spacing', () {
      expect(foldStripped('Frankfurt am Main'), 'frankfurtammain');
      expect(foldStripped("L'Aquila"), 'laquila');
      expect(foldExpanded('Baden-Baden'), 'badenbaden');
    });
  });
}
