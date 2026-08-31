import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether first-run onboarding has been seen (US-010 AC4).
///
/// Three states rather than a boolean. [unknown] is what the app holds for the
/// few frames before storage answers, and it must not be treated as
/// [notCompleted] — doing so would flash the carousel at a returning user on
/// every cold start.
enum OnboardingStatus { unknown, notCompleted, completed }

/// Tracks and persists completion.
///
/// The stored key is `onboarding_completed`, named in AC4. It is also the event
/// name analytics will use, so the two cannot drift.
class OnboardingController extends Notifier<OnboardingStatus> {
  OnboardingController({SharedPreferences? preferences})
      : _preferences = preferences;

  @override
  OnboardingStatus build() {
    unawaited(_restore());
    return OnboardingStatus.unknown;
  }

  /// Storage key and analytics event name. Named by AC4.
  static const String storageKey = 'onboarding_completed';

  SharedPreferences? _preferences;
  bool _decidedThisSession = false;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> _restore() async {
    final prefs = await _prefs;
    final completed = prefs.getBool(storageKey) ?? false;
    // A completion recorded while this read was in flight wins. The same race
    // that re-granted consent in US-008 would here send a user who just
    // finished onboarding back to the start of it.
    if (ref.mounted && !_decidedThisSession) {
      state = completed
          ? OnboardingStatus.completed
          : OnboardingStatus.notCompleted;
    }
  }

  /// Records completion, whether the user read it or skipped it.
  ///
  /// Skipping counts. AC1 makes it skippable, and a user who skips and is asked
  /// again next launch has not really been given the option.
  Future<void> complete() async {
    _decidedThisSession = true;
    state = OnboardingStatus.completed;
    final prefs = await _prefs;
    await prefs.setBool(storageKey, true);
  }

  /// Clears completion so onboarding shows again. For testing and support.
  Future<void> reset() async {
    _decidedThisSession = true;
    state = OnboardingStatus.notCompleted;
    final prefs = await _prefs;
    await prefs.remove(storageKey);
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingStatus>(
        OnboardingController.new);
