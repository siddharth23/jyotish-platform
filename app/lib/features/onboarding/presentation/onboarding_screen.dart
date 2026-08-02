import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/app_formats.dart';
import '../../../core/l10n/generated/app_l10n.dart';
import '../onboarding_controller.dart';

/// One page of the carousel.
@immutable
class OnboardingPage {
  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// First-run onboarding (US-010).
///
/// Four pages, which is the ceiling AC1 sets and is asserted by the tests
/// rather than left as a convention. Skippable from every page, not only the
/// last — an intro that must be read to the end is not skippable, and the user
/// most likely to skip is the one who already knows what the app is.
///
/// Finishing and skipping do the same thing: both mark onboarding complete.
/// Asking again next launch would mean the skip did nothing.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.onFinished, super.key});

  /// Called after completion is recorded. The router supplies this to resume
  /// wherever the user was originally heading.
  final VoidCallback? onFinished;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The pages, in order.
  ///
  /// AC3 requires the free chart, the free career feature and the EUR 11 expert
  /// report to be explained. Those are pages 2 to 4; the first is the welcome.
  List<OnboardingPage> _pages(BuildContext context, AppL10n l10n) => [
        OnboardingPage(
          icon: Icons.auto_awesome_outlined,
          title: l10n.onboardingWelcomeTitle,
          body: l10n.onboardingWelcomeBody,
        ),
        OnboardingPage(
          icon: Icons.grid_on_outlined,
          title: l10n.onboardingChartTitle,
          body: l10n.onboardingChartBody,
        ),
        OnboardingPage(
          icon: Icons.work_outline,
          title: l10n.onboardingCareerTitle,
          body: l10n.onboardingCareerBody,
        ),
        OnboardingPage(
          icon: Icons.article_outlined,
          // Formatted for the locale, so German reads "11,00 €" rather than
          // a bare number with a symbol glued to the wrong end.
          title: l10n.onboardingExpertTitle(AppFormats.euro(context, 11)),
          body: l10n.onboardingExpertBody,
        ),
      ];

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    widget.onFinished?.call();
  }

  void _next(int pageCount) {
    if (_index >= pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: AppMotion.normal, curve: AppMotion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final colors = context.colors;
    final pages = _pages(context, l10n);
    assert(pages.length <= 4, 'US-010 AC1 allows at most four screens.');

    final isLast = _index == pages.length - 1;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip is present on every page, including the last, where it is
            // equivalent to finishing. A control that disappears on the final
            // page makes the user hunt for it.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: AppButton(
                  label: l10n.onboardingSkip,
                  variant: AppButtonVariant.tertiary,
                  size: AppButtonSize.small,
                  onPressed: _finish,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _Page(page: pages[index]),
              ),
            ),
            _PageIndicator(current: _index, total: pages.length),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                label: isLast ? l10n.onboardingStart : l10n.onboardingNext,
                isFullWidth: true,
                size: AppButtonSize.large,
                onPressed: () => _next(pages.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      // Scrollable rather than fixed: German bodies are long, and at large text
      // scales a fixed layout clips the sentence that explains the price.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(page.icon, size: 72, color: colors.primary),
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            header: true,
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style:
                  AppTypography.displayMedium.copyWith(color: colors.onSurface),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Dots, with the position also stated as text for screen readers.
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: AppL10n.of(context).onboardingProgress(current + 1, total),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: AppMotion.fast,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? colors.primary : colors.outline,
                borderRadius: AppRadii.radiusPill,
              ),
            ),
        ],
      ),
    );
  }
}
