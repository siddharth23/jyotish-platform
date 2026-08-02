import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';

/// A shimmering placeholder shown while content loads.
///
/// Hidden from screen readers: announcing a placeholder box is noise, and the
/// surrounding loading state is what should be announced instead.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.radiusXs,
    super.key,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Opacity(
          opacity: 0.4 + (_controller.value * 0.3),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: widget.borderRadius,
            ),
          ),
        ),
      ),
    );
  }
}

/// Several skeleton lines standing in for a paragraph.
class AppSkeletonText extends StatelessWidget {
  const AppSkeletonText({this.lines = 3, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                // The last line is short, as real wrapped text tends to be.
                widthFactor: i == lines - 1 ? 0.6 : 1.0,
                child: const AppSkeleton(),
              ),
            ),
        ],
      );
}
