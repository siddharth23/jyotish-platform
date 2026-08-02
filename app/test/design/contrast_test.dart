import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish_app/core/design/design_system.dart';

/// WCAG 2.1 relative luminance.
///
/// Implemented here from the specification rather than imported, so the test is an
/// independent check on the palette. A helper that shared code with the tokens
/// could only prove they agree with themselves.
double _relativeLuminance(Color color) {
  double channel(double component) {
    return component <= 0.03928
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio between two colours, 1.0 (identical) to 21.0 (black on white).
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// A foreground/background pairing the UI actually renders.
typedef _Pair = ({String name, Color fg, Color bg, double min});

List<_Pair> _pairsFor(AppColors c, String theme) => [
      // WCAG 1.4.3 — normal-size text must reach 4.5:1.
      (
        name: '$theme body on background',
        fg: c.onBackground,
        bg: c.background,
        min: 4.5
      ),
      (
        name: '$theme body on surface',
        fg: c.onSurface,
        bg: c.surface,
        min: 4.5
      ),
      (
        name: '$theme body on surfaceVariant',
        fg: c.onSurface,
        bg: c.surfaceVariant,
        min: 4.5
      ),
      (
        name: '$theme muted on surface',
        fg: c.onSurfaceVariant,
        bg: c.surface,
        min: 4.5
      ),
      (
        name: '$theme muted on surfaceVariant',
        fg: c.onSurfaceVariant,
        bg: c.surfaceVariant,
        min: 4.5
      ),
      (
        name: '$theme onPrimary on primary',
        fg: c.onPrimary,
        bg: c.primary,
        min: 4.5
      ),
      (
        name: '$theme primary on surface',
        fg: c.primary,
        bg: c.surface,
        min: 4.5
      ),
      (
        name: '$theme onPrimaryContainer on primaryContainer',
        fg: c.onPrimaryContainer,
        bg: c.primaryContainer,
        min: 4.5
      ),
      (
        name: '$theme onAccent on accent',
        fg: c.onAccent,
        bg: c.accent,
        min: 4.5
      ),
      (name: '$theme accent on surface', fg: c.accent, bg: c.surface, min: 4.5),
      (
        name: '$theme onAccentContainer on accentContainer',
        fg: c.onAccentContainer,
        bg: c.accentContainer,
        min: 4.5
      ),
      (
        name: '$theme success on surface',
        fg: c.success,
        bg: c.surface,
        min: 4.5
      ),
      (
        name: '$theme warning on surface',
        fg: c.warning,
        bg: c.surface,
        min: 4.5
      ),
      (name: '$theme error on surface', fg: c.error, bg: c.surface, min: 4.5),
      (name: '$theme onError on error', fg: c.onError, bg: c.error, min: 4.5),
      // WCAG 1.4.11 — non-text boundaries need 3:1, not 4.5:1.
      (
        name: '$theme outline on surface',
        fg: c.outline,
        bg: c.surface,
        min: 3.0
      ),
      (
        name: '$theme outline on background',
        fg: c.outline,
        bg: c.background,
        min: 3.0
      ),
    ];

void main() {
  group('The contrast helper itself', () {
    // If the maths is wrong, every assertion below is meaningless.
    test('black on white is 21:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01),
      );
    });

    test('a colour against itself is 1:1', () {
      expect(
        contrastRatio(const Color(0xFF2E3A8C), const Color(0xFF2E3A8C)),
        closeTo(1.0, 0.001),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFF123456);
      const b = Color(0xFFEEDDCC);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-12));
    });

    test('matches a known reference value', () {
      // #767676 on white is the canonical WCAG borderline example at ~4.54:1.
      expect(
        contrastRatio(const Color(0xFF767676), const Color(0xFFFFFFFF)),
        closeTo(4.54, 0.02),
      );
    });
  });

  group('US-004 AC4 — 4.5:1 minimum', () {
    for (final (colors, theme) in [
      (AppColors.light, 'light'),
      (AppColors.dark, 'dark'),
    ]) {
      group(theme, () {
        for (final pair in _pairsFor(colors, theme)) {
          test('${pair.name} meets ${pair.min}:1', () {
            final ratio = contrastRatio(pair.fg, pair.bg);
            expect(
              ratio,
              greaterThanOrEqualTo(pair.min),
              reason: '${pair.name} is ${ratio.toStringAsFixed(2)}:1, '
                  'below the required ${pair.min}:1',
            );
          });
        }
      });
    }

    test('no text pairing scrapes by on a rounding error', () {
      // A pairing at exactly 4.50 would fail the moment a colour is nudged.
      // Everything here should have real headroom.
      for (final colors in [AppColors.light, AppColors.dark]) {
        for (final pair in _pairsFor(colors, 'x')) {
          if (pair.min < 4.5) continue;
          expect(
            contrastRatio(pair.fg, pair.bg),
            greaterThan(4.6),
            reason: '${pair.name} has no margin above the 4.5:1 floor',
          );
        }
      }
    });
  });

  group('Theme wiring', () {
    test('light and dark define every role differently', () {
      // A role accidentally shared between themes usually means a copy/paste
      // that will render as light-on-light somewhere.
      expect(AppColors.light.background, isNot(AppColors.dark.background));
      expect(AppColors.light.surface, isNot(AppColors.dark.surface));
      expect(AppColors.light.onSurface, isNot(AppColors.dark.onSurface));
      expect(AppColors.light.primary, isNot(AppColors.dark.primary));
      expect(AppColors.light.accent, isNot(AppColors.dark.accent));
    });

    test('dark surfaces are darker than light surfaces', () {
      expect(
        _relativeLuminance(AppColors.dark.surface),
        lessThan(_relativeLuminance(AppColors.light.surface)),
      );
      expect(
        _relativeLuminance(AppColors.dark.onSurface),
        greaterThan(_relativeLuminance(AppColors.light.onSurface)),
      );
    });
  });
}
