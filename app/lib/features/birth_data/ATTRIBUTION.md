# Third-party data attribution

## GeoNames

`app/assets/geo/gazetteer.tsv.gz` is derived from the GeoNames geographical database.

- Source: https://www.geonames.org/
- Licence: **Creative Commons Attribution 4.0** — https://creativecommons.org/licenses/by/4.0/
- Files used: `cities5000.txt`, `alternateNamesV2.txt`
- Built by: `scripts/build_gazetteer.py`

CC BY 4.0 requires attribution wherever the work is distributed. **This notice must be
reachable from inside the app** — US-030 AC5 already provides an About screen for the
engine's AGPL notice, and this belongs beside it. Shipping the data without it is a licence
breach, not a documentation gap.

Suggested in-app wording, German:

> Ortsdaten von GeoNames (geonames.org), lizenziert unter CC BY 4.0.

and English:

> Place data from GeoNames (geonames.org), licensed under CC BY 4.0.

CC BY imposes no restriction on the app remaining proprietary and, unlike the AGPL
question in `docs/AGPL-BOUNDARY.md`, carries no source-disclosure obligation. Attribution
is the whole of it.

### Refreshing

```bash
python3 scripts/build_gazetteer.py --out app/assets/geo/gazetteer.tsv.gz
```

Downloads about 200 MB and takes a few minutes. The output is byte-reproducible, so a
rebuild that changes nothing produces an identical file and an empty diff. GeoNames
publishes daily; annually is ample for birth data, since the places people were born in do
not move.
