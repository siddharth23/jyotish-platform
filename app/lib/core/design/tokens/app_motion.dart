import 'package:flutter/animation.dart';

/// Motion durations and curves.
///
/// Short and consistent. Animation here is feedback that something changed, not
/// decoration; anything long enough to notice as an animation is too long to sit
/// through repeatedly.
abstract final class AppMotion {
  /// 80ms — pressed states, ripples.
  static const Duration instant = Duration(milliseconds: 80);

  /// 150ms — hover, selection, small fades.
  static const Duration fast = Duration(milliseconds: 150);

  /// 250ms — the default. Sheets, dialogs, expansion.
  static const Duration normal = Duration(milliseconds: 250);

  /// 400ms — full-screen transitions.
  static const Duration slow = Duration(milliseconds: 400);

  /// Entering the screen — decelerates into place.
  static const Curve enter = Curves.easeOutCubic;

  /// Leaving — accelerates away.
  static const Curve exit = Curves.easeInCubic;

  /// Moving between two on-screen states.
  static const Curve standard = Curves.easeInOutCubic;
}
