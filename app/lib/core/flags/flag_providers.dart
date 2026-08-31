import 'dart:io' show Platform;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_flag.dart';
import 'flag_evaluator.dart';
import 'flag_repository.dart';
import 'flag_rule_set.dart';

/// Identifies the installation for rollout bucketing.
///
/// Overridden at startup with the real account or install id once identity
/// exists (E02). Until then it is a fixed placeholder, which means every device
/// lands in the same bucket — fine while no rollout is configured, and wrong the
/// moment one is, so this must be replaced before the first staged rollout.
final flagUserIdProvider = Provider<String>((ref) => 'anonymous');

/// Whether this is a staff build, for `internalOnly` segments.
final isInternalBuildProvider = Provider<bool>((ref) => kDebugMode);

/// The app version reported to segment rules.
final appVersionProvider = Provider<String>((ref) => '0.1.0');

/// The device locale, as a language code.
final flagLocaleProvider = Provider<String>((ref) => 'de');

final flagContextProvider = Provider<FlagContext>((ref) {
  return FlagContext(
    userId: ref.watch(flagUserIdProvider),
    platform: _platformName,
    appVersion: ref.watch(appVersionProvider),
    locale: ref.watch(flagLocaleProvider),
    isInternal: ref.watch(isInternalBuildProvider),
  );
});

String get _platformName {
  if (kIsWeb) return 'web';
  return Platform.isIOS ? 'ios' : 'android';
}

final flagRepositoryProvider = Provider<FlagRepository>(
  (ref) => FlagRepository(),
);

/// The active rule set.
///
/// Starts empty so the first frame renders on compiled-in defaults rather than
/// waiting on a disk read, then swaps in the cached document. Overridden
/// directly in tests.
class FlagRuleSetController extends Notifier<FlagRuleSet> {
  /// [repository] is optional so the provider can supply it from `ref` in
  /// [build] — a Notifier factory has no ref of its own — while tests can
  /// still hand one in directly.
  FlagRuleSetController([this._injectedRepository]);

  final FlagRepository? _injectedRepository;

  /// Not `late final`: [build] re-runs when a watched dependency changes, and
  /// the Notifier instance is preserved across those runs, so a final field
  /// would throw on the second assignment.
  late FlagRepository _repository;

  @override
  FlagRuleSet build() {
    _repository = _injectedRepository ?? ref.watch(flagRepositoryProvider);
    unawaited(_restore());
    return FlagRuleSet.empty;
  }

  Future<void> _restore() async {
    final cached = await _repository.load();
    // Only adopt the cache if it is actually newer than what is already in
    // state. A fetch can complete while this disk read is still in flight, and
    // an unconditional assignment would let the slower read clobber fresher
    // configuration — including re-enabling a flow that was just killed.
    if (ref.mounted && cached.version > state.version) state = cached;
  }

  /// Applies a freshly fetched document, if it is newer than the cache.
  Future<bool> apply(FlagRuleSet ruleSet) async {
    final stored = await _repository.save(ruleSet);
    if (stored && ref.mounted) state = ruleSet;
    return stored;
  }
}

final flagRuleSetProvider =
    NotifierProvider<FlagRuleSetController, FlagRuleSet>(
  FlagRuleSetController.new,
);

final flagEvaluatorProvider = Provider<FlagEvaluator>((ref) {
  return FlagEvaluator(
    ruleSet: ref.watch(flagRuleSetProvider),
    context: ref.watch(flagContextProvider),
  );
});

/// Whether [flag] is on for this user right now.
final featureFlagProvider = Provider.family<bool, FeatureFlag>(
  (ref, flag) => ref.watch(flagEvaluatorProvider).isEnabled(flag),
);

/// The full evaluation, including why. For support and diagnostics.
final flagEvaluationProvider = Provider.family<FlagEvaluation, FeatureFlag>(
  (ref, flag) => ref.watch(flagEvaluatorProvider).evaluate(flag),
);
