import 'package:shared_preferences/shared_preferences.dart';

import 'social_credential.dart';

/// Device-local storage for what Apple disclosed once (US-012 AC4).
///
/// See [AppleAuthorisationDetails] for why anything is stored at all. In short:
/// Apple gives the address and the name on the first authorisation only, and
/// there is no way to ask again.
///
/// `SharedPreferences` rather than the Keychain. What is held is an address the
/// user has just chosen to share with this app, not a credential — nothing here
/// authenticates anybody, and a Keychain entry survives an uninstall, which for
/// this data would be surprising rather than useful. If it later holds a
/// provider refresh token, that judgement changes and this class moves.
class SharedPreferencesAppleAuthorisationStore
    implements AppleAuthorisationStore {
  SharedPreferencesAppleAuthorisationStore({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  /// Keys are namespaced by subject: one device can hold more than one Apple ID
  /// over its life, and the second must not inherit the first's address.
  static String emailKey(String subjectId) => 'apple_auth_email_$subjectId';
  static String nameKey(String subjectId) => 'apple_auth_name_$subjectId';

  @override
  Future<AppleAuthorisationDetails?> read(String subjectId) async {
    final prefs = await _prefs;
    final email = prefs.getString(emailKey(subjectId));
    final name = prefs.getString(nameKey(subjectId));
    if (email == null && name == null) return null;
    return AppleAuthorisationDetails(
      subjectId: subjectId,
      email: email,
      displayName: name,
    );
  }

  @override
  Future<void> write(AppleAuthorisationDetails details) async {
    final prefs = await _prefs;
    // Null never overwrites a stored value. A second authorisation carries
    // less than the first by design, and letting it win would erase precisely
    // what this class exists to keep. Apple hands back a name in pieces, so a
    // sign-in that yields a name but no address is a real case, not a
    // hypothetical.
    if (details.email != null) {
      await prefs.setString(emailKey(details.subjectId), details.email!);
    }
    if (details.displayName != null) {
      await prefs.setString(nameKey(details.subjectId), details.displayName!);
    }
  }

  @override
  Future<void> clear(String subjectId) async {
    final prefs = await _prefs;
    await prefs.remove(emailKey(subjectId));
    await prefs.remove(nameKey(subjectId));
  }
}

/// An in-memory store, for tests.
class InMemoryAppleAuthorisationStore implements AppleAuthorisationStore {
  final Map<String, AppleAuthorisationDetails> _records = {};

  @override
  Future<AppleAuthorisationDetails?> read(String subjectId) async =>
      _records[subjectId];

  @override
  Future<void> write(AppleAuthorisationDetails details) async {
    final existing = _records[details.subjectId];
    _records[details.subjectId] = AppleAuthorisationDetails(
      subjectId: details.subjectId,
      email: details.email ?? existing?.email,
      displayName: details.displayName ?? existing?.displayName,
    );
  }

  @override
  Future<void> clear(String subjectId) async => _records.remove(subjectId);
}
