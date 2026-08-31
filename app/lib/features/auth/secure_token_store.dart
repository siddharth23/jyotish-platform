/// Where session tokens live on the device (US-016 AC2).
///
/// ## Keychain and Keystore, not shared_preferences
///
/// Everything else this app persists — the theme, the locale, feature flags,
/// whether onboarding has been seen — goes through `shared_preferences`, which
/// on Android is a world-readable-to-root XML file and on iOS a plist inside
/// the app container. That is right for a preference and wrong for a
/// credential: a refresh token *is* the account for sixty days, and on a rooted
/// or jailbroken device a plist is simply a file.
///
/// The Keychain and the Android Keystore are hardware-backed where the device
/// allows it, which means the token is not merely hidden but held somewhere the
/// key material cannot be read out of at all.
///
/// The one behaviour worth knowing: **the iOS Keychain survives an uninstall.**
/// A reinstalled app can find the previous installation's tokens still sitting
/// there. That is why [SecureTokenStore.clear] is called on sign-out rather
/// than trusted to happen when the app is removed, and why a token read at
/// launch is validated against the server before it is believed.
///
/// See `apple_authorisation_store.dart` for the opposite judgement on data that
/// is *not* a credential.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_tokens.dart';

/// Reads and writes the device's session tokens.
abstract interface class SecureTokenStore {
  Future<SessionTokens?> read();
  Future<void> write(SessionTokens tokens);
  Future<void> clear();
}

/// The real store: Keychain on iOS, Keystore-backed cipher storage on Android.
class KeychainTokenStore implements SecureTokenStore {
  KeychainTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? _defaultStorage;

  /// Both platforms need explicit options; the defaults are weaker than this
  /// data warrants.
  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    // `encryptedSharedPreferences: true` used to be set here, and its removal
    // in flutter_secure_storage 11 is not a downgrade. The Jetpack Security
    // (EncryptedSharedPreferences) backend it selected is gone; the plugin now
    // always uses its own Keystore-backed AES-GCM cipher storage, which is what
    // that flag was asking for in the first place.
    //
    // MIGRATION, for whoever upgrades next: v11 removes everything deprecated
    // in v10, and data written by v9 is unreadable after the jump. Going
    // 9 -> 11 directly is only safe because no build with real users has ever
    // stored a token — there is no API to issue one yet. Once there is, the
    // path is 9 -> 10 -> 11, or every user is silently signed out for good.
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      // Not synced to iCloud: a token authorises one device, and a token that
      // follows the user to a new phone outlives the device it was issued to.
      synchronizable: false,
      // Readable only after the first unlock since boot. The app refreshes in
      // the background, so `unlocked` would fail those refreshes;
      // `first_unlock_this_device` still requires the owner to have unlocked
      // the device at least once, and keeps the item off backups.
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  /// One key holding one JSON blob, rather than four keys.
  ///
  /// A partial write is the failure that matters here: an access token stored
  /// without its refresh token is a session that dies in fifteen minutes with
  /// no way back. One key makes the write atomic from this class's point of
  /// view.
  static const String key = 'jyotish_session_tokens_v1';

  @override
  Future<SessionTokens?> read() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SessionTokens.fromJson(decoded);
    } on FormatException {
      // Corrupt blob. Treated as signed out; see [SessionTokens.fromJson].
      return null;
    }
  }

  @override
  Future<void> write(SessionTokens tokens) =>
      _storage.write(key: key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: key);
}

/// For tests and for the widget layer, which must never touch the real
/// Keychain — a plugin call in a widget test throws on the platform channel.
class InMemoryTokenStore implements SecureTokenStore {
  InMemoryTokenStore([this._tokens]);

  SessionTokens? _tokens;

  /// How many times [write] has run. Lets a test assert that a refresh
  /// persisted exactly once.
  int writes = 0;

  @override
  Future<SessionTokens?> read() async => _tokens;

  @override
  Future<void> write(SessionTokens tokens) async {
    _tokens = tokens;
    writes += 1;
  }

  @override
  Future<void> clear() async => _tokens = null;
}
