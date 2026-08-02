import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Severity of an [AppBanner].
enum AppBannerTone { info, success, warning, danger }

/// An inline message attached to the content it concerns.
///
/// Unlike a snackbar it does not time out, so it suits things the user must act on
/// — an SLA at risk, a payment that needs re-authorisation. Every tone pairs an
/// icon with its colour so severity survives greyscale.
class AppBanner extends StatelessWidget {
  const AppBanner({
    required this.message,
    this.title,
    this.tone = AppBannerTone.info,
    this.onDismiss,
    this.dismissTooltip,
    super.key,
  });

  final String message;
  final String? title;
  final AppBannerTone tone;
  final VoidCallback? onDismiss;
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    assert(
      onDismiss == null || dismissTooltip != null,
      'A dismissible banner needs dismissTooltip so the control can be announced.',
    );
    final colors = context.colors;

    final (Color foreground, IconData icon) = switch (tone) {
      AppBannerTone.info => (colors.primary, Icons.info_outline),
      AppBannerTone.success => (colors.success, Icons.check_circle_outline),
      AppBannerTone.warning => (colors.warning, Icons.warning_amber_outlined),
      AppBannerTone.danger => (colors.error, Icons.error_outline),
    };

    return Semantics(
      liveRegion: tone == AppBannerTone.danger,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.10),
          borderRadius: AppRadii.radiusSm,
          border: Border.all(color: foreground.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppTypography.titleSmall
                          .copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  Text(
                    message,
                    style: AppTypography.bodyMedium
                        .copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: Semantics(
                  button: true,
                  label: dismissTooltip,
                  child: const SizedBox(
                    width: AppSpacing.minTapTarget,
                    height: AppSpacing.minTapTarget,
                    child: Icon(Icons.close, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
