import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/flags/feature_flag.dart';
import 'package:jyotish_app/core/flags/flag_evaluator.dart';
import 'package:jyotish_app/core/flags/flag_repository.dart';
import 'package:jyotish_app/core/flags/flag_rule_set.dart';
import 'package:shared_preferences/shared_preferences.dart';

FlagRuleSet killSwitchOff(int version) => FlagRuleSet(
      version: version,
      rules: const {
        'paid_evaluation': FlagRule(key: 'paid_evaluation', enabled: false),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FlagRepository> repository(
      [Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return FlagRepository(preferences: await SharedPreferences.getInstance());
  }

  group('Cold start', () {
    test('no cache yields an empty rule set, not an error', () async {
      final repo = await repository();
      final loaded = await repo.load();
      expect(loaded.version, 0);
      expect(loaded.rules, isEmpty);
    });

    test('an empty rule set means every flag uses its default', () async {
      final repo = await repository();
      final evaluator = FlagEvaluator(
        ruleSet: await repo.load(),
        context: const FlagContext(
          userId: 'u',
          platform: 'android',
          appVersion: '1.0.0',
          locale: 'de',
        ),
      );
      expect(
        evaluator.isEnabled(FeatureFlag.paidEvaluation),
        FeatureFlag.paidEvaluation.defaultValue,
      );
    });
  });

  group('The cache is what makes the kill switch stick', () {
    test('a saved document survives being reloaded', () async {
      final repo = await repository();
      expect(await repo.save(killSwitchOff(5)), isTrue);

      final loaded = await repo.load();
      expect(loaded.version, 5);
      expect(loaded.rules['paid_evaluation']!.enabled, isFalse);
    });

    test('the paid flow stays off across a restart with no network', () async {
      // The scenario the cache exists for: the switch was flipped, the device
      // later has no connectivity, and the app must not revert to the
      // compiled-in default of "on" and start taking orders again.
      final first = await repository();
      await first.save(killSwitchOff(5));

      final persisted = SharedPreferences.getInstance();
      final second = FlagRepository(preferences: await persisted);
      final evaluator = FlagEvaluator(
        ruleSet: await second.load(),
        context: const FlagContext(
          userId: 'u',
          platform: 'android',
          appVersion: '1.0.0',
          locale: 'de',
        ),
      );
      expect(evaluator.isEnabled(FeatureFlag.paidEvaluation), isFalse);
    });
  });

  group('Version monotonicity', () {
    test('a newer document replaces an older one', () async {
      final repo = await repository();
      await repo.save(killSwitchOff(1));
      expect(await repo.save(killSwitchOff(2)), isTrue);
      expect((await repo.load()).version, 2);
    });

    test('an older document is rejected', () async {
      // A stale CDN edge or an out-of-order retry must not resurrect a flag
      // that has since been killed.
      final repo = await repository();
      await repo.save(killSwitchOff(9));
      expect(await repo.save(killSwitchOff(3)), isFalse);
      expect((await repo.load()).version, 9);
    });

    test('the same version is rejected, so republishing needs a bump',
        () async {
      final repo = await repository();
      await repo.save(killSwitchOff(4));
      expect(await repo.save(killSwitchOff(4)), isFalse);
    });
  });

  group('Corruption', () {
    test('unparseable cached JSON degrades to defaults', () async {
      // A corrupted cache must not prevent the app from starting.
      final repo = await repository({'feature_flags_document': 'not json {{{'});
      final loaded = await repo.load();
      expect(loaded.version, 0);
      expect(loaded.rules, isEmpty);
    });

    test('valid JSON of the wrong shape degrades too', () async {
      final repo = await repository({'feature_flags_document': '[1,2,3]'});
      expect((await repo.load()).rules, isEmpty);
    });
  });

  group('A slow disk read must not clobber fresher configuration', () {
    test('save keeps the newer version when both arrive', () async {
      // The race this guards: the controller starts reading the cache, a fetch
      // completes first and applies version 5, then the older disk read
      // resolves. Adopting it unconditionally would drop back to version 1 and
      // silently re-enable a flow that had just been killed.
      final repo = await repository();
      await repo.save(killSwitchOff(1));

      final staleRead = repo.load();
      await repo.save(killSwitchOff(5));
      final stale = await staleRead;

      expect(stale.version, lessThanOrEqualTo(5));
      // Whatever the read returned, storage holds the newer document.
      expect((await repo.load()).version, 5);
    });
  });

  group('Clearing', () {
    test('drops back to defaults', () async {
      final repo = await repository();
      await repo.save(killSwitchOff(5));
      await repo.clear();
      expect((await repo.load()).version, 0);
    });
  });
}
