import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'flag_rule_set.dart';

/// Loads and caches the served rule set.
///
/// **The cache is what makes a kill switch trustworthy.** Once configuration has
/// been fetched it survives restarts and network loss, so turning the paid flow
/// off reaches a client that later goes offline. Without it, every launch
/// without a network would revert to the compiled-in defaults and quietly
/// re-enable whatever was killed.
///
/// The document is fetched by the caller and handed to [save]; this class does
/// no networking, so it stays testable and has no opinion about transport.
class FlagRepository {
  FlagRepository({SharedPreferences? preferences}) : _preferences = preferences;

  static const String _storageKey = 'feature_flags_document';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  /// The cached rule set, or [FlagRuleSet.empty] if there is none.
  ///
  /// Malformed cached JSON returns empty rather than throwing: a corrupted
  /// cache must degrade to compiled-in defaults, not prevent the app starting.
  Future<FlagRuleSet> load() async {
    final raw = (await _prefs).getString(_storageKey);
    if (raw == null) return FlagRuleSet.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return FlagRuleSet.empty;
      return FlagRuleSet.fromJson(decoded);
    } on FormatException {
      return FlagRuleSet.empty;
    }
  }

  /// Stores [ruleSet] if it is newer than what is cached.
  ///
  /// Returns whether it was stored. Older documents are rejected: a stale CDN
  /// edge or a retried request arriving out of order must not resurrect a flag
  /// that has since been killed. Equal versions are also rejected, so a
  /// republished document has to increment its version to take effect.
  Future<bool> save(FlagRuleSet ruleSet) async {
    final cached = await load();
    if (ruleSet.version <= cached.version) return false;
    await (await _prefs).setString(_storageKey, jsonEncode(ruleSet.toJson()));
    return true;
  }

  /// Drops the cache. For sign-out, and for support to reset a device to
  /// compiled-in defaults.
  Future<void> clear() async => (await _prefs).remove(_storageKey);
}
