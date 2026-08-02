import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crash-free session rate for one app version.
@immutable
class CrashFreeRate {
  const CrashFreeRate({
    required this.appVersion,
    required this.totalSessions,
    required this.crashedSessions,
  });

  final String appVersion;
  final int totalSessions;
  final int crashedSessions;

  int get cleanSessions => totalSessions - crashedSessions;

  /// Percentage of sessions that ended without a crash.
  ///
  /// A version with no sessions returns 100, not 0. Zero would read as a total
  /// outage and, with the 99% alert in `infra/observability/alerts.yaml`, would
  /// page someone the moment a release is cut and before anyone has run it.
  double get percentage =>
      totalSessions == 0 ? 100 : (cleanSessions / totalSessions) * 100;

  /// Whether this breaches the US-008 AC3 threshold.
  ///
  /// Guarded by a minimum sample: one crash in the first three sessions of a
  /// release is 67%, which is alarming and meaningless. The threshold is about
  /// a release's health, not its first few minutes.
  bool breaches({double threshold = 99.0, int minimumSessions = 50}) =>
      totalSessions >= minimumSessions && percentage < threshold;

  Map<String, Object?> toJson() => {
        'appVersion': appVersion,
        'totalSessions': totalSessions,
        'crashedSessions': crashedSessions,
        'crashFreePercent': double.parse(percentage.toStringAsFixed(3)),
      };

  @override
  String toString() => '$appVersion: ${percentage.toStringAsFixed(2)}% '
      '($cleanSessions/$totalSessions clean)';
}

/// Tracks sessions to derive the crash-free rate (US-008 AC1).
///
/// ## How a crash is detected
///
/// There is no callback for "the process was killed". Instead a session is
/// marked open on start and cleared on a clean exit; if the next launch finds
/// one still open, the previous session did not end cleanly.
///
/// That over-counts: a user force-quitting from the app switcher, or the OS
/// reclaiming memory in the background, both look like crashes. It is the same
/// approximation Crashlytics and Sentry make, and it errs towards reporting
/// worse stability than reality — which is the safer direction for a metric
/// that gates a release.
///
/// ## Consent
///
/// Counters are local. Nothing here transmits, so this runs regardless of
/// consent; only [CrashReporter] is gated. Keeping the metric local means a
/// user who refuses telemetry still gets an app that knows whether it crashed
/// on its own last run.
class SessionTracker {
  SessionTracker({
    required String appVersion,
    SharedPreferences? preferences,
  })  : _appVersion = appVersion,
        _preferences = preferences;

  static const String _openSessionKey = 'session_open_version';
  static const String _totalPrefix = 'session_total_';
  static const String _crashedPrefix = 'session_crashed_';

  final String _appVersion;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  /// Opens a session, and returns whether the previous one ended in a crash.
  ///
  /// The crash is attributed to the version that was running at the time, not
  /// the one starting now — otherwise a release that fixes a crash inherits it
  /// from the version it replaced.
  Future<bool> startSession() async {
    final prefs = await _prefs;
    final previouslyOpen = prefs.getString(_openSessionKey);

    var crashed = false;
    if (previouslyOpen != null) {
      crashed = true;
      await _increment(prefs, '$_crashedPrefix$previouslyOpen');
    }

    await _increment(prefs, '$_totalPrefix$_appVersion');
    await prefs.setString(_openSessionKey, _appVersion);
    return crashed;
  }

  /// Marks the session as having ended cleanly.
  Future<void> endSession() async {
    final prefs = await _prefs;
    await prefs.remove(_openSessionKey);
  }

  /// The rate for the running version.
  Future<CrashFreeRate> currentRate() => rateFor(_appVersion);

  /// The rate for any version still on the device.
  Future<CrashFreeRate> rateFor(String appVersion) async {
    final prefs = await _prefs;
    return CrashFreeRate(
      appVersion: appVersion,
      totalSessions: prefs.getInt('$_totalPrefix$appVersion') ?? 0,
      crashedSessions: prefs.getInt('$_crashedPrefix$appVersion') ?? 0,
    );
  }

  /// Rates for every version this device has recorded, newest counters first.
  ///
  /// Per release, not lifetime: a crash fixed three versions ago should not
  /// keep dragging the current number down.
  Future<List<CrashFreeRate>> allRates() async {
    final prefs = await _prefs;
    final versions = prefs
        .getKeys()
        .where((key) => key.startsWith(_totalPrefix))
        .map((key) => key.substring(_totalPrefix.length))
        .toSet();

    final rates = [for (final version in versions) await rateFor(version)];
    rates.sort((a, b) => b.totalSessions.compareTo(a.totalSessions));
    return rates;
  }

  /// Clears counters for versions other than the current one.
  ///
  /// Bounded storage: without this, a long-lived install accumulates a counter
  /// pair for every version it has ever run.
  Future<void> pruneOtherVersions() async {
    final prefs = await _prefs;
    for (final key in prefs.getKeys().toList()) {
      final isCounter =
          key.startsWith(_totalPrefix) || key.startsWith(_crashedPrefix);
      if (isCounter && !key.endsWith(_appVersion)) {
        await prefs.remove(key);
      }
    }
  }

  Future<void> _increment(SharedPreferences prefs, String key) async {
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }
}
