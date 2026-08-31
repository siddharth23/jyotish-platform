import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the light/dark override.
///
/// Mirrors `LocaleController`: [ThemeMode.system] means keep following the
/// device, so a user whose phone switches to dark at sunset sees the app follow
/// rather than stay pinned to whatever it resolved to on first launch.
///
/// Starts at [ThemeMode.system] and updates when storage answers. Blocking the
/// first frame on a disk read to avoid a brief flash would cost more than the
/// flash does.
class ThemeController extends Notifier<ThemeMode> {
  ThemeController({SharedPreferences? preferences})
      : _preferences = preferences;

  static const String _storageKey = 'theme_mode';

  SharedPreferences? _preferences;

  @override
  ThemeMode build() {
    unawaited(_restore());
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    _preferences ??= await SharedPreferences.getInstance();
    final stored = _preferences!.getString(_storageKey);
    if (stored != null && ref.mounted) {
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_storageKey, mode.name);
  }

  /// Flips between light and dark, resolving [ThemeMode.system] against what is
  /// currently on screen so the first tap always visibly changes something.
  Future<void> toggle({required bool isCurrentlyDark}) =>
      select(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
