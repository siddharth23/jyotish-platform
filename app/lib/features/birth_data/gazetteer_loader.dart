/// Loads the bundled gazetteer off the UI thread.
///
/// The asset is about 1.6 MB gzipped and roughly 3 MB of text once expanded,
/// which becomes ~70,000 objects with their folded search keys. Doing that
/// synchronously on the platform thread drops frames on any phone, and it
/// would happen exactly when the user first taps the birthplace field.
///
/// `compute` moves the gunzip and the parse to another isolate. The asset load
/// itself has to stay on this side — the asset bundle is not available to a
/// plain background isolate.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';
import 'dart:io';
import 'place.dart';

/// Decoded once per app run and shared.
final gazetteerProvider = FutureProvider<Gazetteer>((ref) async {
  final bytes = await rootBundle.load(gazetteerAssetPath);
  return decodeGazetteer(bytes.buffer.asUint8List());
});

const String gazetteerAssetPath = 'assets/geo/gazetteer.tsv.gz';

/// Gunzips and parses, on a background isolate.
Future<Gazetteer> decodeGazetteer(Uint8List compressed) =>
    compute(_decode, compressed);

Gazetteer _decode(Uint8List compressed) {
  final expanded = gzip.decode(compressed);
  return Gazetteer.parse(utf8.decode(expanded));
}
