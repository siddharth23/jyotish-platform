import 'package:flutter/foundation.dart';

/// Who a flag is being evaluated for.
///
/// [userId] is the stable identifier the rollout bucket is derived from. It must
/// survive reinstalls for the bucket to be stable; an id regenerated per launch
/// would move a user in and out of a 10% rollout on every start.
@immutable
class FlagContext {
  const FlagContext({
    required this.userId,
    required this.platform,
    required this.appVersion,
    required this.locale,
    this.isInternal = false,
  });

  final String userId;

  /// 'android' or 'ios'.
  final String platform;

  /// 'major.minor.patch'.
  final String appVersion;

  /// Language code, e.g. 'de'.
  final String locale;

  /// Staff build.
  final bool isInternal;
}

/// A targeting rule. The first matching segment decides the flag and skips the
/// percentage rollout.
@immutable
class FlagSegment {
  const FlagSegment({
    required this.value,
    this.name,
    this.locales,
    this.platforms,
    this.minAppVersion,
    this.maxAppVersion,
    this.userIds,
    this.internalOnly,
  });

  final bool value;
  final String? name;
  final List<String>? locales;
  final List<String>? platforms;
  final String? minAppVersion;
  final String? maxAppVersion;
  final List<String>? userIds;
  final bool? internalOnly;

  /// Whether [context] falls in this segment.
  ///
  /// Every criterion present must hold; absent criteria do not constrain. A
  /// segment with no criteria at all therefore matches everyone, which is a
  /// legitimate way to express "override the base value for all users".
  bool matches(FlagContext context) {
    if (locales != null && !locales!.contains(context.locale)) return false;
    if (platforms != null && !platforms!.contains(context.platform)) {
      return false;
    }
    if (userIds != null && !userIds!.contains(context.userId)) return false;
    if (internalOnly == true && !context.isInternal) return false;
    if (minAppVersion != null &&
        compareVersions(context.appVersion, minAppVersion!) < 0) {
      return false;
    }
    if (maxAppVersion != null &&
        compareVersions(context.appVersion, maxAppVersion!) > 0) {
      return false;
    }
    return true;
  }

  static FlagSegment fromJson(Map<String, Object?> json) => FlagSegment(
        value: _bool(json['value']) ?? false,
        name: _string(json['name']),
        locales: _stringList(json['locales']),
        platforms: _stringList(json['platforms']),
        minAppVersion: _string(json['minAppVersion']),
        maxAppVersion: _string(json['maxAppVersion']),
        userIds: _stringList(json['userIds']),
        internalOnly: _bool(json['internalOnly']),
      );

  static List<String>? _stringList(Object? value) =>
      value is List ? [for (final item in value) item.toString()] : null;
}

// The served document is untrusted input: a bad deploy, a hand-edited row or a
// schema change can put the wrong type in any field. A cast that throws here
// would crash the app on launch, which is a far worse failure than a flag
// falling back to its default — so every field is checked rather than cast.
bool? _bool(Object? value) => value is bool ? value : null;
String? _string(Object? value) => value is String ? value : null;
int? _int(Object? value) => value is num ? value.toInt() : null;

/// One flag's configuration as served.
@immutable
class FlagRule {
  const FlagRule({
    required this.key,
    required this.enabled,
    this.rollout,
    this.segments = const [],
  });

  final String key;
  final bool enabled;

  /// 0-100. Null means everyone.
  final int? rollout;

  final List<FlagSegment> segments;

  static FlagRule fromJson(Map<String, Object?> json) => FlagRule(
        key: _string(json['key']) ?? '',
        enabled: _bool(json['enabled']) ?? false,
        rollout: _int(json['rollout']),
        segments: [
          for (final segment in (json['segments'] as List? ?? const []))
            if (segment is Map<String, Object?>) FlagSegment.fromJson(segment),
        ],
      );
}

/// A published set of flag rules.
@immutable
class FlagRuleSet {
  const FlagRuleSet({
    required this.version,
    required this.rules,
    this.issuedAt,
  });

  /// Empty set — every flag falls back to its compiled-in default.
  static const FlagRuleSet empty = FlagRuleSet(version: 0, rules: {});

  /// Monotonic. A document with a lower version than the cached one is ignored,
  /// so a stale CDN edge cannot resurrect a flag that was killed.
  final int version;

  final Map<String, FlagRule> rules;
  final DateTime? issuedAt;

  static FlagRuleSet fromJson(Map<String, Object?> json) {
    final rules = <String, FlagRule>{};
    for (final entry in (json['flags'] as List? ?? const [])) {
      if (entry is! Map<String, Object?>) continue;
      final rule = FlagRule.fromJson(entry);
      if (rule.key.isNotEmpty) rules[rule.key] = rule;
    }
    return FlagRuleSet(
      version: _int(json['version']) ?? 0,
      rules: rules,
      issuedAt: DateTime.tryParse(_string(json['issuedAt']) ?? ''),
    );
  }

  Map<String, Object?> toJson() => {
        'version': version,
        if (issuedAt != null) 'issuedAt': issuedAt!.toUtc().toIso8601String(),
        'flags': [
          for (final rule in rules.values)
            {
              'key': rule.key,
              'enabled': rule.enabled,
              if (rule.rollout != null) 'rollout': rule.rollout,
              if (rule.segments.isNotEmpty)
                'segments': [
                  for (final segment in rule.segments)
                    {
                      'value': segment.value,
                      if (segment.name != null) 'name': segment.name,
                      if (segment.locales != null) 'locales': segment.locales,
                      if (segment.platforms != null)
                        'platforms': segment.platforms,
                      if (segment.minAppVersion != null)
                        'minAppVersion': segment.minAppVersion,
                      if (segment.maxAppVersion != null)
                        'maxAppVersion': segment.maxAppVersion,
                      if (segment.userIds != null) 'userIds': segment.userIds,
                      if (segment.internalOnly != null)
                        'internalOnly': segment.internalOnly,
                    },
                ],
            },
        ],
      };
}

/// Compares 'major.minor.patch' strings numerically.
///
/// Not a string comparison: '1.10.0' is newer than '1.9.0' but sorts before it
/// lexically, so a max-version rule written to disable a flag for buggy 1.9
/// builds would also catch every 1.10 build.
///
/// Missing or non-numeric components are treated as 0, so a malformed version
/// from a client compares as oldest rather than throwing during evaluation.
int compareVersions(String a, String b) {
  final left = _parts(a);
  final right = _parts(b);
  for (var i = 0; i < 3; i++) {
    final difference = left[i] - right[i];
    if (difference != 0) return difference.sign;
  }
  return 0;
}

List<int> _parts(String version) {
  final segments = version.split('.');
  return [
    for (var i = 0; i < 3; i++)
      i < segments.length ? (int.tryParse(segments[i].trim()) ?? 0) : 0,
  ];
}
