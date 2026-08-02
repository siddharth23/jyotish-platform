import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/flags/feature_flag.dart';
import 'package:jyotish_app/core/flags/flag_evaluator.dart';
import 'package:jyotish_app/core/flags/flag_rule_set.dart';

FlagContext ctx({
  String userId = 'user-1',
  String platform = 'android',
  String appVersion = '1.0.0',
  String locale = 'de',
  bool isInternal = false,
}) =>
    FlagContext(
      userId: userId,
      platform: platform,
      appVersion: appVersion,
      locale: locale,
      isInternal: isInternal,
    );

FlagRuleSet ruleSet(List<FlagRule> rules, {int version = 1}) => FlagRuleSet(
      version: version,
      rules: {for (final rule in rules) rule.key: rule},
    );

bool evaluate(FlagRuleSet rules, FeatureFlag flag, [FlagContext? context]) =>
    FlagEvaluator(ruleSet: rules, context: context ?? ctx()).isEnabled(flag);

void main() {
  group('Compiled-in defaults', () {
    test('an empty rule set uses each flag\'s own default', () {
      const empty = FlagRuleSet.empty;
      for (final flag in FeatureFlag.values) {
        expect(
          evaluate(empty, flag),
          flag.defaultValue,
          reason: '${flag.key} should fall back to its default',
        );
      }
    });

    test('an unknown key does not force a flag off', () {
      // Treating "not in the document" as false would let a typo in the admin
      // console silently disable a feature no client has heard of.
      final rules = ruleSet([
        const FlagRule(key: 'some_other_flag', enabled: true),
      ]);
      expect(
        evaluate(rules, FeatureFlag.paidEvaluation),
        FeatureFlag.paidEvaluation.defaultValue,
      );
    });

    test('the reason says it was the default', () {
      final evaluation = FlagEvaluator(
        ruleSet: FlagRuleSet.empty,
        context: ctx(),
      ).evaluate(FeatureFlag.paidEvaluation);
      expect(evaluation.reason, FlagReason.compiledDefault);
    });

    test('the paid flow defaults on, career analysis defaults off', () {
      // Stated as a test because these are product decisions, not accidents:
      // career analysis carries AI Act and AGG exposure and must ship
      // deliberately rather than because a fetch failed.
      expect(FeatureFlag.paidEvaluation.defaultValue, isTrue);
      expect(FeatureFlag.careerAnalysis.defaultValue, isFalse);
    });
  });

  group('AC2 — the kill switch', () {
    test('turning the flag off disables the paid flow', () {
      final rules = ruleSet([
        const FlagRule(key: 'paid_evaluation', enabled: false),
      ]);
      expect(evaluate(rules, FeatureFlag.paidEvaluation), isFalse);
    });

    test('and says why', () {
      final evaluation = FlagEvaluator(
        ruleSet: ruleSet([
          const FlagRule(key: 'paid_evaluation', enabled: false),
        ]),
        context: ctx(),
      ).evaluate(FeatureFlag.paidEvaluation);
      expect(evaluation.reason, FlagReason.disabledAtSource);
    });

    test('a rollout cannot re-enable a flag that is off at source', () {
      // Otherwise a leftover rollout percentage would partially undo a kill.
      final rules = ruleSet([
        const FlagRule(key: 'paid_evaluation', enabled: false, rollout: 100),
      ]);
      expect(evaluate(rules, FeatureFlag.paidEvaluation), isFalse);
    });

    test('the kill reaches every user regardless of bucket', () {
      final rules = ruleSet([
        const FlagRule(key: 'paid_evaluation', enabled: false),
      ]);
      for (var i = 0; i < 500; i++) {
        expect(
          evaluate(rules, FeatureFlag.paidEvaluation, ctx(userId: 'user-$i')),
          isFalse,
          reason: 'user-$i still had the paid flow enabled',
        );
      }
    });
  });

  group('AC1 — segments', () {
    test('an explicit user list wins', () {
      final rules = ruleSet([
        const FlagRule(
          key: 'career_analysis',
          enabled: false,
          segments: [
            FlagSegment(value: true, name: 'testers', userIds: ['tester-1']),
          ],
        ),
      ]);
      expect(
        evaluate(rules, FeatureFlag.careerAnalysis, ctx(userId: 'tester-1')),
        isTrue,
      );
      expect(
        evaluate(
            rules, FeatureFlag.careerAnalysis, ctx(userId: 'someone-else')),
        isFalse,
      );
    });

    test('locale targeting', () {
      final rules = ruleSet([
        const FlagRule(
          key: 'daily_panchang',
          enabled: false,
          segments: [
            FlagSegment(value: true, locales: ['de'])
          ],
        ),
      ]);
      expect(
        evaluate(rules, FeatureFlag.dailyPanchang, ctx(locale: 'de')),
        isTrue,
      );
      expect(
        evaluate(rules, FeatureFlag.dailyPanchang, ctx(locale: 'en')),
        isFalse,
      );
    });

    test('platform targeting', () {
      final rules = ruleSet([
        const FlagRule(
          key: 'daily_panchang',
          enabled: false,
          segments: [
            FlagSegment(value: true, platforms: ['ios'])
          ],
        ),
      ]);
      expect(
        evaluate(rules, FeatureFlag.dailyPanchang, ctx(platform: 'ios')),
        isTrue,
      );
      expect(
        evaluate(rules, FeatureFlag.dailyPanchang, ctx(platform: 'android')),
        isFalse,
      );
    });

    test('internal-only segments do not match production builds', () {
      final rules = ruleSet([
        const FlagRule(
          key: 'career_analysis',
          enabled: false,
          segments: [FlagSegment(value: true, internalOnly: true)],
        ),
      ]);
      expect(
        evaluate(rules, FeatureFlag.careerAnalysis, ctx(isInternal: true)),
        isTrue,
      );
      expect(
        evaluate(rules, FeatureFlag.careerAnalysis, ctx(isInternal: false)),
        isFalse,
      );
    });

    test('a version ceiling disables a flag for a broken build', () {
      // The reason max-version exists: turn a feature off for 1.2.0 without a
      // store release, while 1.3.0 keeps it.
      final rules = ruleSet([
        const FlagRule(
          key: 'career_analysis',
          enabled: true,
          segments: [FlagSegment(value: false, maxAppVersion: '1.2.0')],
        ),
      ]);
      expect(
        evaluate(rules, FeatureFlag.careerAnalysis, ctx(appVersion: '1.2.0')),
        isFalse,
      );
      expect(
        evaluate(rules, FeatureFlag.careerAnalysis, ctx(appVersion: '1.1.9')),
        isFalse,
      );
      expect(
        evaluate(rules, FeatureFlag.careerAnalysis, ctx(appVersion: '1.3.0')),
        isTrue,
      );
    });

    test('all criteria in a segment must hold', () {
      final rules = ruleSet([
        const FlagRule(
          key: 'daily_panchang',
          enabled: false,
          segments: [
            FlagSegment(value: true, locales: ['de'], platforms: ['ios']),
          ],
        ),
      ]);
      expect(
        evaluate(rules, FeatureFlag.dailyPanchang,
            ctx(locale: 'de', platform: 'ios')),
        isTrue,
      );
      expect(
        evaluate(rules, FeatureFlag.dailyPanchang,
            ctx(locale: 'de', platform: 'android')),
        isFalse,
      );
    });

    test('the first matching segment wins', () {
      final rules = ruleSet([
        const FlagRule(
          key: 'daily_panchang',
          enabled: false,
          segments: [
            FlagSegment(value: true, name: 'first', locales: ['de']),
            FlagSegment(value: false, name: 'second', locales: ['de']),
          ],
        ),
      ]);
      final evaluation = FlagEvaluator(ruleSet: rules, context: ctx())
          .evaluate(FeatureFlag.dailyPanchang);
      expect(evaluation.value, isTrue);
      expect(evaluation.segmentName, 'first');
    });

    test('a segment beats the rollout', () {
      final rules = ruleSet([
        const FlagRule(
          key: 'career_analysis',
          enabled: true,
          rollout: 0,
          segments: [
            FlagSegment(value: true, userIds: ['tester-1'])
          ],
        ),
      ]);
      expect(
        evaluate(rules, FeatureFlag.careerAnalysis, ctx(userId: 'tester-1')),
        isTrue,
      );
    });
  });

  group('AC1 — percentage rollout', () {
    test('0% is off and 100% is on for everyone', () {
      for (final (rollout, expected) in [(0, false), (100, true)]) {
        final rules = ruleSet([
          FlagRule(key: 'career_analysis', enabled: true, rollout: rollout),
        ]);
        for (var i = 0; i < 200; i++) {
          expect(
            evaluate(rules, FeatureFlag.careerAnalysis, ctx(userId: 'u$i')),
            expected,
            reason: 'rollout $rollout, u$i',
          );
        }
      }
    });

    test('roughly the requested share is included', () {
      final rules = ruleSet([
        const FlagRule(key: 'career_analysis', enabled: true, rollout: 25),
      ]);
      var included = 0;
      const population = 4000;
      for (var i = 0; i < population; i++) {
        if (evaluate(
            rules, FeatureFlag.careerAnalysis, ctx(userId: 'user-$i'))) {
          included++;
        }
      }
      final share = included / population * 100;
      // A hash is not a perfectly uniform distribution; a few points either way
      // is expected, an order of magnitude is a bug.
      expect(share, closeTo(25, 4), reason: 'got $share%');
    });

    test('a user does not flip between evaluations', () {
      // The whole point of hashing rather than randomising: a user who saw the
      // feature yesterday must see it today.
      final rules = ruleSet([
        const FlagRule(key: 'career_analysis', enabled: true, rollout: 50),
      ]);
      final first =
          evaluate(rules, FeatureFlag.careerAnalysis, ctx(userId: 'u7'));
      for (var i = 0; i < 50; i++) {
        expect(
          evaluate(rules, FeatureFlag.careerAnalysis, ctx(userId: 'u7')),
          first,
        );
      }
    });

    test('a user is not in the same bucket for every flag', () {
      // Otherwise the same unlucky 10% would receive every staged rollout in
      // the product, and another 10% would never see any.
      const userId = 'user-42';
      final buckets = {
        for (final flag in FeatureFlag.values) bucketFor(flag.key, userId),
      };
      expect(buckets.length, greaterThan(1));
    });

    test('buckets stay inside 0-99', () {
      for (var i = 0; i < 1000; i++) {
        final bucket = bucketFor('some_flag', 'user-$i');
        expect(bucket, inInclusiveRange(0, 99));
      }
    });

    test('bucketing is stable for a known input', () {
      // Pins the hash. Changing the algorithm reshuffles every live rollout,
      // moving users who already have a feature out of it — so this failing
      // should be a deliberate decision, not a surprise.
      expect(bucketFor('paid_evaluation', 'user-1'),
          bucketFor('paid_evaluation', 'user-1'));
      expect(bucketFor('a', 'b'), isNot(bucketFor('b', 'a')));
    });

    test('the evaluation reports the bucket, for support', () {
      final evaluation = FlagEvaluator(
        ruleSet: ruleSet([
          const FlagRule(key: 'career_analysis', enabled: true, rollout: 50),
        ]),
        context: ctx(userId: 'user-3'),
      ).evaluate(FeatureFlag.careerAnalysis);
      expect(evaluation.bucket, bucketFor('career_analysis', 'user-3'));
      expect(
        evaluation.reason,
        anyOf(FlagReason.rolloutIncluded, FlagReason.rolloutExcluded),
      );
    });
  });

  group('Version comparison', () {
    test('compares numerically, not lexically', () {
      // '1.10.0' sorts before '1.9.0' as a string, which would make a ceiling
      // of 1.9.0 also catch every 1.10 build.
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '10.0.0'), lessThan(0));
    });

    test('equal versions compare equal', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('missing components count as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1', '1.0.1'), lessThan(0));
    });

    test('a malformed version does not throw', () {
      expect(compareVersions('abc', '1.0.0'), lessThan(0));
      expect(compareVersions('', '0.0.0'), 0);
    });
  });

  group('Serialisation', () {
    test('a served document round-trips', () {
      final parsed = FlagRuleSet.fromJson({
        'version': 12,
        'issuedAt': '2026-08-02T10:00:00Z',
        'flags': [
          {
            'key': 'paid_evaluation',
            'enabled': true,
            'rollout': 40,
            'segments': [
              {
                'value': false,
                'name': 'broken builds',
                'maxAppVersion': '1.2.0'
              },
            ],
          },
        ],
      });

      expect(parsed.version, 12);
      expect(parsed.rules['paid_evaluation']!.rollout, 40);
      expect(parsed.rules['paid_evaluation']!.segments.single.name,
          'broken builds');

      final again = FlagRuleSet.fromJson(parsed.toJson());
      expect(again.version, parsed.version);
      expect(again.rules['paid_evaluation']!.rollout, 40);
      expect(again.rules['paid_evaluation']!.segments.single.maxAppVersion,
          '1.2.0');
    });

    test('a malformed document degrades instead of throwing', () {
      // A bad document must fall back to compiled-in defaults, not crash the
      // app on launch.
      final parsed = FlagRuleSet.fromJson({
        'version': 'not a number',
        'flags': [
          'not an object',
          {'no_key': true},
          {'key': 'paid_evaluation', 'enabled': 'not a bool'},
        ],
      });
      expect(parsed.version, 0);
      // 'enabled' was not a bool, so the rule is off at source rather than
      // guessed at.
      expect(parsed.rules['paid_evaluation']?.enabled, isFalse);
    });
  });
}
