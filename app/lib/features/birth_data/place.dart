/// Birthplace search over a bundled gazetteer (US-021).
///
/// ## The search never leaves the device
///
/// A birthplace is part of a birth record, and under CLAUDE.md any processor
/// touching personal data needs a signed DPA and an EU data plane. A
/// type-ahead against a hosted geocoder would ship a fragment of someone's
/// birth record off-device on every keystroke — dozens of transfers to build
/// one chart, each one a transfer to justify. Bundling the data removes the
/// processor entirely, costs nothing per request, and works offline, which the
/// app already promises for saved kundalis.
///
/// The backlog files US-021 under "Backend". This is a deliberate departure,
/// and the vendor sheet points the same way: "Bundle GeoNames offline where
/// possible to cut this to zero."
///
/// ## Folding is where German input actually breaks
///
/// Somebody looking for München will type `münchen`, `Munchen` or `Muenchen`,
/// and all three have to work. Diacritic stripping alone gets the first two and
/// misses the third, because German transliteration expands rather than strips:
/// ä→ae, ö→oe, ü→ue, ß→ss. So every name is indexed under both foldings — the
/// stripped one and the expanded one — and the query is matched against both.
///
/// The same applies to Turkish (ı, ş, ğ, ç) for AC3, where the dotless ı folds
/// to i and a naive `toLowerCase` on İ produces a combining sequence that
/// matches nothing.
///
/// LICENSING: no engine code. Data is GeoNames, CC BY 4.0 — see ATTRIBUTION.md.
library;

/// A populated place a chart can be cast for.
class Place {
  const Place({
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.timeZoneId,
    required this.population,
    this.admin1,
  });

  /// German where GeoNames has a German name: München, not Munich.
  final String name;

  /// ISO 3166-1 alpha-2.
  final String countryCode;

  /// Four decimals, about 11 m. AC2.
  final double latitude;
  final double longitude;

  /// IANA zone for the place, e.g. `Europe/Berlin`.
  ///
  /// Carried here because US-022 needs a zone for the coordinates and this is
  /// the moment we already know it. It is **not** the offset: the offset
  /// depends on the birth *date* as well, and German double summer time and
  /// India's pre-1955 offset are US-022's problem, not this file's.
  final String timeZoneId;

  final int population;

  /// GeoNames admin1 code — Bundesland, state, province. Disambiguates the
  /// several Neustadts.
  final String? admin1;

  @override
  String toString() => '$name ($countryCode)';
}

/// Strips diacritics: München → munchen, İzmir → izmir.
String foldStripped(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    buffer.write(_stripped[rune] ?? String.fromCharCode(rune));
  }
  return _collapse(buffer.toString());
}

/// Expands German umlauts the way Germans type them: München → muenchen.
String foldExpanded(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    buffer
        .write(_expanded[rune] ?? _stripped[rune] ?? String.fromCharCode(rune));
  }
  return _collapse(buffer.toString());
}

/// Drops everything that is not a letter or digit.
///
/// Place names carry hyphens, apostrophes and spaces that people type
/// inconsistently — Baden-Baden, Frankfurt am Main, L'Aquila, Sant Julià. The
/// index and the query are collapsed the same way so none of it matters.
String _collapse(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final isDigit = rune >= 0x30 && rune <= 0x39;
    final isLetter = rune >= 0x61 && rune <= 0x7a;
    if (isDigit || isLetter) buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

const Map<int, String> _expanded = {
  0xE4: 'ae', // ä
  0xF6: 'oe', // ö
  0xFC: 'ue', // ü
  0xDF: 'ss', // ß
};

const Map<int, String> _stripped = {
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a', 0x101: 'a',
  0xE7: 'c', 0x107: 'c', 0x10D: 'c',
  0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e', 0x113: 'e', 0x11B: 'e',
  0x11F: 'g', // ğ
  0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i', 0x12B: 'i',
  0x131: 'i', // ı — dotless, Turkish
  0x130: 'i', // İ
  0xF1: 'n', 0x144: 'n',
  0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o', 0x14D: 'o',
  0x15F: 's', 0x15B: 's', 0x161: 's', // ş ś š
  0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u', 0x16B: 'u',
  0xFD: 'y', 0xFF: 'y',
  0x17A: 'z', 0x17C: 'z', 0x17E: 'z',
  0xDF: 'ss',
};

/// One searchable entry: a place plus every name it answers to.
class _Indexed {
  _Indexed(this.place, this.keys);
  final Place place;

  /// Folded forms of the display name and every alias, both foldings.
  final List<String> keys;
}

/// An in-memory gazetteer.
///
/// Loaded once from the bundled asset. Roughly 70,000 places — small enough to
/// hold and scan linearly, large enough that the scan must not happen on the
/// UI thread during the first frame. [GazetteerLoader] does the decode off the
/// main isolate.
class Gazetteer {
  Gazetteer(this._entries) : _exact = _buildExactIndex(_entries);

  final List<_Indexed> _entries;

  /// Folded name to the places answering to exactly that name.
  ///
  /// Exists because population ranking alone gets the obvious case wrong:
  /// typing "Konstanz" matched Romania's Konstanza first, since it is four
  /// times the size and "konstanz" is a prefix of "konstanza". An exact name
  /// match is a much stronger signal of intent than population, so it wins.
  final Map<String, List<Place>> _exact;

  int get size => _entries.length;

  static Map<String, List<Place>> _buildExactIndex(List<_Indexed> entries) {
    final index = <String, List<Place>>{};
    for (final entry in entries) {
      for (final key in entry.keys) {
        (index[key] ??= <Place>[]).add(entry.place);
      }
    }
    return index;
  }

  /// Parses the decompressed asset.
  ///
  /// Format: the timezone table, a blank line, then one place per line —
  /// `name, aliases (| separated), lat, lon, country, admin1, population,
  /// timezone index`, ordered by population descending. Written by
  /// `scripts/build_gazetteer.py`.
  factory Gazetteer.parse(String source) {
    final split = source.indexOf('\n\n');
    if (split < 0) {
      throw const FormatException('Gazetteer has no timezone table.');
    }

    final zones = source.substring(0, split).split('\n');
    final entries = <_Indexed>[];

    for (final line in source.substring(split + 2).split('\n')) {
      if (line.isEmpty) continue;
      final f = line.split('\t');
      if (f.length < 8) continue;

      final zoneIndex = int.parse(f[7]);
      final place = Place(
        name: f[0],
        countryCode: f[4],
        latitude: double.parse(f[2]),
        longitude: double.parse(f[3]),
        timeZoneId: zones[zoneIndex],
        population: int.parse(f[6]),
        admin1: f[5].isEmpty ? null : f[5],
      );

      final names = <String>[f[0], if (f[1].isNotEmpty) ...f[1].split('|')];
      final keys = <String>{};
      for (final name in names) {
        keys.add(foldStripped(name));
        keys.add(foldExpanded(name));
      }
      keys.remove('');
      entries.add(_Indexed(place, keys.toList(growable: false)));
    }
    return Gazetteer(entries);
  }

  /// Type-ahead. AC1.
  ///
  /// Prefix matching, not substring: someone typing `ber` means Berlin, not
  /// Heidelberg, and substring matching buries the obvious answer under
  /// hundreds of towns that merely contain the letters.
  ///
  /// Results come back population-descending because the source is already in
  /// that order, so the scan can stop as soon as it has [limit] hits and still
  /// have returned the places a user most likely meant. That is what keeps a
  /// 70,000-row linear scan fast enough to run on every keystroke.
  List<Place> search(String query, {int limit = 8}) {
    final stripped = foldStripped(query);
    final expanded = foldExpanded(query);
    if (stripped.isEmpty) return const [];

    final results = <Place>[];
    final seen = <Place>{};

    // Exact matches first, in population order. O(1) rather than a scan, and
    // it is what stops a larger city whose name merely starts with the query
    // from burying the town the user actually named.
    for (final key in {stripped, expanded}) {
      for (final place in _exact[key] ?? const <Place>[]) {
        if (seen.add(place)) results.add(place);
        if (results.length >= limit) return results;
      }
    }

    // Then prefix matches, population-descending because the source is already
    // in that order — so the scan can stop as soon as it has enough and still
    // have returned the places a user most likely meant. That is what keeps a
    // 70,000-row scan fast enough to run on every keystroke.
    for (final entry in _entries) {
      if (seen.contains(entry.place)) continue;
      for (final key in entry.keys) {
        if (key.startsWith(stripped) || key.startsWith(expanded)) {
          if (seen.add(entry.place)) results.add(entry.place);
          break;
        }
      }
      if (results.length >= limit) break;
    }
    return results;
  }
}
