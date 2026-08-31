import 'dart:ui' show Locale;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The locales the app ships.
///
/// German first: content is authored in German and translated to English. The
/// order matters — Flutter falls back to the first entry when the device locale
/// matches nothing, and an unmatched user should land on German, the market this
/// product is built for.
const List<Locale> supportedLocales = [
  Locale('de', 'DE'),
  Locale('en', 'GB'),
];

/// What the user chose in settings.
///
/// [system] is not a locale — it means "keep following the device", so that a
/// user who changes their phone's language sees the app follow rather than stay
/// pinned to whatever it resolved to on first launch.
enum LocalePreference {
  system,
  german,
  english;

  /// The locale to force, or null to follow the device.
  Locale? get locale => switch (this) {
        LocalePreference.system => null,
        LocalePreference.german => const Locale('de', 'DE'),
        // en-GB, not bare 'en': the language code alone makes intl fall back to
        // US conventions, so a date would render 'May 17, 1990' rather than
        // '17/05/1990' and a British customer would see American formatting.
        LocalePreference.english => const Locale('en', 'GB'),
      };

  static LocalePreference fromStorage(String? value) => switch (value) {
        'de' => LocalePreference.german,
        'en' => LocalePreference.english,
        _ => LocalePreference.system,
      };

  String get storageValue => switch (this) {
        LocalePreference.system => 'system',
        LocalePreference.german => 'de',
        LocalePreference.english => 'en',
      };
}

/// Persists and exposes the language override.
///
/// Loading is asynchronous but the app must not block on it, so the controller
/// starts at [LocalePreference.system] — the correct default anyway — and updates
/// once storage answers. The visible effect of a stored override is a brief first
/// frame in the device language, which is preferable to a splash screen.
class LocaleController extends Notifier<LocalePreference> {
  LocaleController({SharedPreferences? preferences})
      : _preferences = preferences;

  @override
  LocalePreference build() {
    unawaited(_restore());
    return LocalePreference.system;
  }

  static const String _storageKey = 'locale_preference';

  SharedPreferences? _preferences;

  Future<void> _restore() async {
    _preferences ??= await SharedPreferences.getInstance();
    final stored = _preferences!.getString(_storageKey);
    if (stored != null && ref.mounted) {
      state = LocalePreference.fromStorage(stored);
    }
  }

  /// Sets the override and persists it.
  Future<void> select(LocalePreference preference) async {
    state = preference;
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_storageKey, preference.storageValue);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, LocalePreference>(LocaleController.new);
