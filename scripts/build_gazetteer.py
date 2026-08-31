#!/usr/bin/env python3
"""Builds the offline birthplace gazetteer from GeoNames (US-021).

WHY THIS IS BUNDLED RATHER THAN CALLED AS AN API

A birthplace is personal data, and under CLAUDE.md every processor touching
personal data needs a signed DPA and an EU data plane. A type-ahead against a
third-party geocoder sends a fragment of someone's birth record off-device on
every keystroke — dozens of transfers to build one chart. Bundling the data
means the query never leaves the phone: no processor, no DPA, no transfer
question, no per-request cost, and it works offline, which the app already
promises for saved kundalis (US-005).

The backlog files US-021 under "Backend". This is a deliberate departure, taken
because the privacy answer and the vendor sheet ("Bundle GeoNames offline where
possible to cut this to zero") both point the other way.

WHY THE LANGUAGE-TAGGED FILE IS NEEDED

GeoNames' primary `name` column is frequently the *English* exonym: Munich, not
München; Milan, not Mailand. Shipping that to a German-first audience would be
wrong on the most visible field on the screen.

The `alternatenames` column in cities5000 is no help — it is an untagged blob
mixing every language on earth, so searching it matches Hungarian and Japanese
transliterations of the same town. The language-tagged alternateNamesV2 export
carries an ISO language code and an isPreferredName flag, which yields:

  - the German display name           (München, Mailand, Prag, Warschau)
  - the ASCII form Germans type        (Muenchen, Koeln)
  - historical names people still use  (Bombay for Mumbai, Constantinople)

all as data, rather than as a hand-curated exonym table that would be wrong the
first time somebody was born somewhere we forgot.

LICENCE: GeoNames is CC BY 4.0. Attribution is required and lives in
`app/lib/features/birth_data/ATTRIBUTION.md`, surfaced in-app under About.

USAGE
    python3 scripts/build_gazetteer.py --out app/assets/geo/gazetteer.tsv.gz

Downloads ~200 MB and takes a few minutes. Re-run when refreshing the dataset;
GeoNames publishes daily, but annually is plenty for birth data.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import io
import sys
import tempfile
import urllib.request
import zipfile
from collections import defaultdict
from pathlib import Path

BASE = 'https://download.geonames.org/export/dump/'

# Cities above 5,000 people. cities15000 misses most German Kreisstädte, and
# cities1000 doubles the asset for towns almost nobody is born in — there is no
# maternity ward in a village of 1,200.
CITIES = 'cities5000'


def download(name: str, member: str, into: Path) -> Path:
    target = into / member
    if target.exists():
        return target
    url = f'{BASE}{name}.zip'
    print(f'  downloading {url}', file=sys.stderr)
    archive = into / f'{name}.zip'
    urllib.request.urlretrieve(url, archive)
    with zipfile.ZipFile(archive) as z:
        z.extract(member, into)
    return target


def build(work: Path) -> bytes:
    cities = download(CITIES, f'{CITIES}.txt', work)
    alternates = download('alternateNamesV2', 'alternateNamesV2.txt', work)

    # Feature class P is "city, village, ..." — populated places. Everything
    # else in the file is administrative or geographic and nobody is born "in"
    # a mountain range.
    wanted: set[str] = set()
    with cities.open(encoding='utf-8') as f:
        for p in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
            if len(p) >= 18 and p[6] == 'P':
                wanted.add(p[0])

    de_preferred: dict[str, str] = {}
    de_names: dict[str, set[str]] = defaultdict(set)
    en_names: dict[str, set[str]] = defaultdict(set)

    print(f'  scanning alternate names for {len(wanted):,} places', file=sys.stderr)
    with alternates.open(encoding='utf-8') as f:
        for p in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
            if len(p) < 4:
                continue
            gid, language, name = p[1], p[2], p[3]
            if gid not in wanted or language not in ('de', 'en') or not name.strip():
                continue
            # isColloquial (column 7): nicknames like "Phoenix City" for
            # Warsaw. Useful trivia, wrong in a birth record.
            #
            # isHistoric (column 8) is deliberately NOT excluded. Someone born
            # in 1970 says Bombay, not Mumbai, and Constantinople still gets
            # typed — historic names are exactly what a birth record needs.
            if len(p) > 6 and p[6] == '1':
                continue
            if language == 'de':
                de_names[gid].add(name)
                if len(p) > 4 and p[4] == '1':
                    de_preferred[gid] = name
            else:
                en_names[gid].add(name)

    timezones: dict[str, int] = {}
    rows: list[tuple[str, str, float, float, str, str, int, int]] = []

    with cities.open(encoding='utf-8') as f:
        for p in csv.reader(f, delimiter='\t', quoting=csv.QUOTE_NONE):
            if len(p) < 18 or p[6] != 'P':
                continue
            gid, name, ascii_name = p[0], p[1], p[2]
            lat, lon, country, admin1, population, timezone = p[4], p[5], p[8], p[10], p[14], p[17]

            display = de_preferred.get(gid)
            if display is None and name in de_names.get(gid, ()):
                # No flagged preference, but GeoNames' own primary name is
                # itself German — Konstanz, Bamberg, Görlitz. Use it.
                #
                # This case is load-bearing. Konstanz carries the archaic
                # "Costnitz" as an alternate German name, and picking the
                # shortest would have shipped a spelling last current in about
                # 1800 as the label on a birth record.
                display = name
            if display is None and de_names.get(gid):
                # Still nothing authoritative: the shortest German name is the
                # plain one. The long ones are "Landeshauptstadt München".
                #
                # The name itself breaks length ties. Sorting on length alone
                # falls back to set iteration order, which Python randomises
                # per process — the build would then emit different bytes each
                # run, and nobody could check that the committed asset came
                # from the committed script.
                display = sorted(de_names[gid], key=lambda n: (len(n), n))[0]
            if display is None:
                display = name

            aliases = {name, ascii_name} | de_names.get(gid, set()) | en_names.get(gid, set())
            aliases.discard(display)
            aliases.discard('')

            if timezone not in timezones:
                timezones[timezone] = len(timezones)

            rows.append((
                display,
                '|'.join(sorted(aliases)),
                # Four decimals is roughly 11 m — far finer than a birth record
                # justifies, and AC2's requirement. More would be false
                # precision, and the log redaction in the API treats four or
                # more decimals as personal data.
                round(float(lat), 4),
                round(float(lon), 4),
                country,
                admin1,
                int(population or 0),
                timezones[timezone],
            ))

    # Population-descending, so a prefix scan can stop early and still have
    # returned the places a user most likely meant.
    rows.sort(key=lambda r: -r[6])

    out = io.StringIO()
    out.write('\n'.join(sorted(timezones, key=timezones.get)))
    out.write('\n\n')
    for row in rows:
        out.write('\t'.join(str(value) for value in row))
        out.write('\n')

    print(f'  {len(rows):,} places, {len(timezones)} timezones', file=sys.stderr)
    # mtime=0, or gzip stamps the current time into the header and two runs of
    # this script produce different bytes from identical data — which would
    # make it impossible to check that the committed asset came from the
    # committed script.
    return gzip.compress(out.getvalue().encode('utf-8'), 9, mtime=0)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--work', type=Path, default=None,
                        help='Where to cache the downloads. Defaults to a temp dir.')
    args = parser.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        work = args.work or Path(tmp)
        work.mkdir(parents=True, exist_ok=True)
        payload = build(work)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(payload)
    print(f'wrote {args.out} ({len(payload) / 1048576:.2f} MB)', file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
