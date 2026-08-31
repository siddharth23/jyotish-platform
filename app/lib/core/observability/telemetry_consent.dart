import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Consent for optional telemetry (US-008 AC4).
///
/// `docs/COMPLIANCE.md`: "CMP fires before any analytics or crash SDK". Crash
/// reporting sends device and diagnostic data to a processor outside our
/// control, which under GDPR needs a lawful basis, and for non-essential
/// telemetry that basis is consent. This type is the gate; the consent *UI* is
/// US-095's job, and it will drive [TelemetryConsentController].
///
/// Categories are separate because consenting to crash reports is not
/// consenting to product analytics. Bundling them makes the consent invalid —
/// it has to be specific.
enum TelemetryCategory {
  /// Crashes and ANRs. Stack traces, device model, OS version, app version.
  crashReporting,

  /// Timings — start-up, screen render, request latency.
  performance,
}

/// Whether a category may be collected.
///
/// [unknown] is a distinct state from [denied] on purpose. "Not asked yet" and
/// "asked and refused" behave the same in the moment — nothing is sent — but
/// only one of them means the CMP should be shown, and only one of them may
/// later be flushed to a processor.
enum ConsentState { unknown, granted, denied }

/// Consent per category.
class TelemetryConsent {
  const TelemetryConsent({
    this.crashReporting = ConsentState.unknown,
    this.performance = ConsentState.unknown,
  });

  /// Nothing decided. What every fresh install starts on.
  static const TelemetryConsent none = TelemetryConsent();

  final ConsentState crashReporting;
  final ConsentState performance;

  ConsentState stateOf(TelemetryCategory category) => switch (category) {
        TelemetryCategory.crashReporting => crashReporting,
        TelemetryCategory.performance => performance,
      };

  /// Whether [category] may leave the device.
  ///
  /// Only [ConsentState.granted] permits it. This is the single check the whole
  /// story rests on, which is why it is a positive test against one value
  /// rather than `!= denied` — the latter would treat "not asked yet" as
  /// permission.
  bool allows(TelemetryCategory category) =>
      stateOf(category) == ConsentState.granted;

  /// Whether the CMP still needs to ask about anything.
  bool get needsDecision =>
      crashReporting == ConsentState.unknown ||
      performance == ConsentState.unknown;

  TelemetryConsent copyWith({
    ConsentState? crashReporting,
    ConsentState? performance,
  }) =>
      TelemetryConsent(
        crashReporting: crashReporting ?? this.crashReporting,
        performance: performance ?? this.performance,
      );

  Map<String, String> toStorage() => {
        'crashReporting': crashReporting.name,
        'performance': performance.name,
      };

  static TelemetryConsent fromStorage(Map<String, String?> stored) {
    ConsentState read(String key) {
      final value = stored[key];
      // Anything unrecognised — a corrupted value, a state removed in a later
      // version — is treated as not yet decided. It must never read as granted.
      return ConsentState.values
              .where((state) => state.name == value)
              .firstOrNull ??
          ConsentState.unknown;
    }

    return TelemetryConsent(
      crashReporting: read('crashReporting'),
      performance: read('performance'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TelemetryConsent &&
      other.crashReporting == crashReporting &&
      other.performance == performance;

  @override
  int get hashCode => Object.hash(crashReporting, performance);

  @override
  String toString() =>
      'TelemetryConsent(crash: ${crashReporting.name}, perf: ${performance.name})';
}

/// Holds and persists the user's choices.
///
/// Starts at [TelemetryConsent.none] and only ever moves to a stored value.
/// Loading is asynchronous, so for a few frames after launch the app behaves as
/// though nothing is consented — which is the correct direction for the race to
/// fail in.
class TelemetryConsentController extends Notifier<TelemetryConsent> {
  TelemetryConsentController({SharedPreferences? preferences})
      : _preferences = preferences;

  @override
  TelemetryConsent build() {
    unawaited(_restore());
    return TelemetryConsent.none;
  }

  static const String _crashKey = 'consent_crash_reporting';
  static const String _performanceKey = 'consent_performance';

  SharedPreferences? _preferences;

  /// Whether the user has decided anything since this controller was created.
  ///
  /// Guards the restore-from-disk below.
  bool _decidedThisSession = false;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> _restore() async {
    final prefs = await _prefs;
    final restored = TelemetryConsent.fromStorage({
      'crashReporting': prefs.getString(_crashKey),
      'performance': prefs.getString(_performanceKey),
    });
    // A decision made while this read was in flight wins. Without this guard a
    // slow disk read silently overwrites the user's choice — and in the
    // dangerous direction: someone taps "reject all", the read resolves with a
    // previously stored "granted", and crash reports start flowing from a user
    // who just refused them.
    if (ref.mounted && !_decidedThisSession) state = restored;
  }

  /// Records a decision for one category.
  Future<void> set(TelemetryCategory category, ConsentState decision) async {
    _decidedThisSession = true;
    state = switch (category) {
      TelemetryCategory.crashReporting =>
        state.copyWith(crashReporting: decision),
      TelemetryCategory.performance => state.copyWith(performance: decision),
    };
    final prefs = await _prefs;
    await prefs.setString(
      switch (category) {
        TelemetryCategory.crashReporting => _crashKey,
        TelemetryCategory.performance => _performanceKey,
      },
      decision.name,
    );
  }

  /// Accepts everything. Called by the CMP's accept-all control.
  Future<void> grantAll() async {
    for (final category in TelemetryCategory.values) {
      await set(category, ConsentState.granted);
    }
  }

  /// Refuses everything.
  ///
  /// `COMPLIANCE.md` requires reject-all to be as prominent as accept-all, so
  /// this must stay exactly as easy to call — and as easy to reach in the UI —
  /// as [grantAll].
  Future<void> denyAll() async {
    for (final category in TelemetryCategory.values) {
      await set(category, ConsentState.denied);
    }
  }

  /// Returns to the undecided state, so the CMP asks again.
  ///
  /// Withdrawing consent must be as easy as giving it. Anything already sent to
  /// a processor is not recalled by this; deletion there is a data-subject
  /// request (US-096).
  Future<void> reset() async {
    _decidedThisSession = true;
    state = TelemetryConsent.none;
    final prefs = await _prefs;
    await prefs.remove(_crashKey);
    await prefs.remove(_performanceKey);
  }
}

final telemetryConsentProvider =
    NotifierProvider<TelemetryConsentController, TelemetryConsent>(
        TelemetryConsentController.new);
