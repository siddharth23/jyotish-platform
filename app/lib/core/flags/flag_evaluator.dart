import 'feature_flag.dart';
import 'flag_rule_set.dart';

/// Why a flag came out the way it did.
///
/// Carried alongside the value so support can answer "why can this user not
/// order an evaluation?" without guessing. A flag system that only returns a
/// boolean is unanswerable the moment someone reports something odd.
enum FlagReason {
  /// No rule set loaded, or no rule for this key.
  compiledDefault,

  /// A segment matched and decided it.
  segment,

  /// The base value, with no rollout in play.
  baseValue,

  /// Inside the rollout percentage.
  rolloutIncluded,

  /// Outside the rollout percentage.
  rolloutExcluded,

  /// Base value was false, so the rollout never applied.
  disabledAtSource,
}

/// The outcome of evaluating one flag.
class FlagEvaluation {
  const FlagEvaluation({
    required this.flag,
    required this.value,
    required this.reason,
    this.segmentName,
    this.bucket,
  });

  final FeatureFlag flag;
  final bool value;
  final FlagReason reason;

  /// Which segment decided it, when [reason] is [FlagReason.segment].
  final String? segmentName;

  /// The user's 0-99 bucket for this flag, when a rollout was consulted.
  final int? bucket;

  @override
  String toString() => 'FlagEvaluation(${flag.key}=$value, ${reason.name}'
      '${segmentName == null ? '' : ', segment=$segmentName'}'
      '${bucket == null ? '' : ', bucket=$bucket'})';
}

/// Evaluates flags locally against a rule set.
///
/// Pure and synchronous: no I/O, no clock, no randomness. The same context and
/// rule set always produce the same answer, which is what makes a rollout
/// reproducible and this class fully testable.
class FlagEvaluator {
  const FlagEvaluator({required this.ruleSet, required this.context});

  final FlagRuleSet ruleSet;
  final FlagContext context;

  bool isEnabled(FeatureFlag flag) => evaluate(flag).value;

  FlagEvaluation evaluate(FeatureFlag flag) {
    final rule = ruleSet.rules[flag.key];
    if (rule == null) {
      // Unknown to this rule set — including the case where nothing has been
      // fetched. The compiled-in default is the answer, not false.
      return FlagEvaluation(
        flag: flag,
        value: flag.defaultValue,
        reason: FlagReason.compiledDefault,
      );
    }

    // Segments win over the rollout: an explicit allow-list for a named tester,
    // or a max-version rule disabling a flag for a broken build, must not be
    // subject to a percentage.
    for (final segment in rule.segments) {
      if (segment.matches(context)) {
        return FlagEvaluation(
          flag: flag,
          value: segment.value,
          reason: FlagReason.segment,
          segmentName: segment.name,
        );
      }
    }

    if (!rule.enabled) {
      return FlagEvaluation(
        flag: flag,
        value: false,
        reason: FlagReason.disabledAtSource,
      );
    }

    final rollout = rule.rollout;
    if (rollout == null || rollout >= 100) {
      return FlagEvaluation(
        flag: flag,
        value: true,
        reason: FlagReason.baseValue,
      );
    }
    if (rollout <= 0) {
      return FlagEvaluation(
        flag: flag,
        value: false,
        reason: FlagReason.rolloutExcluded,
        bucket: bucketFor(flag.key, context.userId),
      );
    }

    final bucket = bucketFor(flag.key, context.userId);
    final included = bucket < rollout;
    return FlagEvaluation(
      flag: flag,
      value: included,
      reason:
          included ? FlagReason.rolloutIncluded : FlagReason.rolloutExcluded,
      bucket: bucket,
    );
  }
}

/// The user's stable 0-99 bucket for a flag.
///
/// The flag key is part of the hash input, so a user is not in the same bucket
/// for every flag. Without it, the first 10% of users would receive every
/// staged rollout in the product and the last 10% would never see any — the
/// same small group absorbing all the risk, repeatedly.
///
/// Uses FNV-1a rather than [Object.hashCode], which Dart does not guarantee to
/// be stable across runs or platforms. A bucket that changes between launches
/// would move users in and out of a rollout at random.
int bucketFor(String flagKey, String userId) {
  const int offsetBasis = 0x811c9dc5;
  const int prime = 0x01000193;
  const int mask = 0xffffffff;

  var hash = offsetBasis;
  for (final unit in '$flagKey:$userId'.codeUnits) {
    hash = (hash ^ unit) & mask;
    hash = (hash * prime) & mask;
  }
  return hash % 100;
}
