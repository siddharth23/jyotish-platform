import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';
import '../account_linking.dart';
import '../auth_controller.dart';
import '../social_provider.dart';

/// The sign-in screen (US-012).
///
/// ## Button order is a compliance requirement, not a design preference
///
/// The provider list comes from [SocialSignInAvailability.providersFor], which
/// puts Apple first on iOS and returns nothing at all if Apple is unavailable
/// there. Neither rule is re-implemented here. A screen that builds its own
/// list is a screen that can ship a Guideline 4.8 violation, and that decision
/// has one home.
///
/// Email and password (US-011) sits below the social buttons and is always
/// present. It is the flow that works when a provider SDK does not, and on a
/// platform with no social providers at all it is the whole screen.
/// Maps Flutter's target platform onto the sign-in rules' [SignInPlatform].
///
/// Takes the platform as an argument rather than reading `defaultTargetPlatform`
/// itself, so a widget test can drive the iOS rules on a Linux CI machine —
/// which is the only way the Guideline 4.8 behaviour gets exercised before
/// review does it for us.
SignInPlatform signInPlatformFor(TargetPlatform platform) => switch (platform) {
      TargetPlatform.iOS => SignInPlatform.ios,
      TargetPlatform.android => SignInPlatform.android,
      _ => SignInPlatform.other,
    };

class SignInScreen extends ConsumerWidget {
  const SignInScreen({
    required this.platform,
    this.onSignedIn,
    this.onContinueWithEmail,
    super.key,
  });

  /// Passed in rather than read from `Platform`, so the compliance rules can be
  /// exercised for every platform in a widget test.
  final SignInPlatform platform;

  final void Function(AuthSignedIn)? onSignedIn;
  final VoidCallback? onContinueWithEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final colors = context.colors;
    final state = ref.watch(authControllerProvider);
    final providers = ref.watch(availableSocialProvidersProvider(platform));

    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is AuthSignedIn) onSignedIn?.call(next);
    });

    return AppScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          // Scrollable, because German labels wrap to two lines and the
          // relay notice is four lines at large text scales.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.signInTitle,
                  style: AppTypography.displayMedium
                      .copyWith(color: colors.onSurface),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.signInBody,
                style: AppTypography.bodyLarge
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (state is AuthFailure) ...[
                AppBanner(
                  message: _failureMessage(l10n, state.reason),
                  tone: AppBannerTone.danger,
                  onDismiss: () => ref
                      .read(authControllerProvider.notifier)
                      .dismissFailure(),
                  // Required by AppBanner: a dismiss control a screen reader
                  // cannot announce is a control it cannot reach.
                  dismissTooltip: l10n.commonClose,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              // The link prompt replaces the provider buttons rather than
              // sitting beside them. Leaving the buttons live would let a
              // second authorisation start on top of an undecided prompt, and
              // the credential held for that decision would be replaced
              // underneath it.
              if (state is AuthAwaitingLinkDecision)
                LinkAccountPrompt(
                  decision: state.decision,
                  onContinueWithEmail: onContinueWithEmail,
                )
              else ...[
                providers.when(
                  loading: () => const AppProgressIndicator(),
                  // Failing to enumerate providers is not failing to sign in.
                  // The email flow below still works, so the screen says so
                  // rather than covering a working alternative with an error.
                  error: (_, __) =>
                      _SocialUnavailable(message: l10n.signInSocialUnavailable),
                  data: (available) => available.isEmpty
                      ? _SocialUnavailable(
                          message: l10n.signInSocialUnavailable,
                        )
                      : _SocialButtons(
                          providers: available,
                          state: state,
                          onPressed: (provider) => ref
                              .read(authControllerProvider.notifier)
                              .signInWith(provider),
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Divider(label: l10n.signInDivider),
                const SizedBox(height: AppSpacing.lg),
                // Hidden behind the link prompt along with the provider
                // buttons: the prompt carries its own way out, and a second
                // identical control below it is two answers to one question.
                AppButton(
                  label: l10n.signInWithEmail,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.large,
                  isFullWidth: true,
                  onPressed: onContinueWithEmail,
                ),
              ],
              if (state is AuthSignedIn && state.usedPrivateRelay) ...[
                const SizedBox(height: AppSpacing.xl),
                _PrivateRelayNotice(
                  title: l10n.signInPrivateRelayTitle,
                  body: l10n.signInPrivateRelayBody,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _failureMessage(AppL10n l10n, AuthFailureReason reason) =>
      switch (reason) {
        AuthFailureReason.network => l10n.signInErrorNetwork,
        AuthFailureReason.providerUnavailable =>
          l10n.signInErrorProviderUnavailable,
        AuthFailureReason.tokenRejected => l10n.signInErrorTokenRejected,
        AuthFailureReason.notImplemented => l10n.signInErrorNotImplemented,
        AuthFailureReason.unknown => l10n.signInErrorUnknown,
      };
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons({
    required this.providers,
    required this.state,
    required this.onPressed,
  });

  final List<SocialProvider> providers;
  final AuthState state;
  final void Function(SocialProvider) onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Bound to a local so the type test promotes: `state` is a field, and a
    // field is not promoted by `is` because another object could change it.
    final current = state;
    final busy = current is AuthInProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in providers) ...[
          AppButton(
            label: switch (provider) {
              SocialProvider.apple => l10n.signInWithApple,
              SocialProvider.google => l10n.signInWithGoogle,
            },
            icon: switch (provider) {
              SocialProvider.apple => Icons.apple,
              SocialProvider.google => Icons.g_mobiledata,
            },
            size: AppButtonSize.large,
            isFullWidth: true,
            // Every button goes quiet while any provider is working. Leaving
            // the others live invites a second sheet on top of the first.
            isLoading: busy && current.provider == provider,
            onPressed: busy ? null : () => onPressed(provider),
          ),
          if (provider != providers.last) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SocialUnavailable extends StatelessWidget {
  const _SocialUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => AppBanner(
        message: message,
        tone: AppBannerTone.info,
      );
}

class _Divider extends StatelessWidget {
  const _Divider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        const Expanded(child: AppDivider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: AppTypography.bodySmall
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        const Expanded(child: AppDivider()),
      ],
    );
  }
}

/// Shown once, immediately after an account is created behind Hide My Email.
///
/// The consequence, not the mechanism: the €11 report is delivered by email,
/// and a forwarding address the user later switches off makes their order
/// undeliverable. Saying only "your address is hidden" would be reassuring and
/// useless.
class _PrivateRelayNotice extends StatelessWidget {
  const _PrivateRelayNotice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTypography.bodyMedium
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the provider buttons when an account already exists for
/// the address (US-012 AC3).
///
/// Rendered inline rather than as a modal on purpose. This is a decision the
/// user has to make before anything else on the screen means anything, and an
/// inline prompt cannot be dismissed by a stray tap outside it — which for a
/// dialog would drop them back on a sign-in screen with no explanation of what
/// just happened.
///
/// Two shapes, decided by the API and never by this widget:
///
/// - [LinkToExistingAccount] — the provider verified the address, so linking is
///   safe and the prompt offers it.
/// - [ProofOfControlRequired] — it did not, so **there is no link button at
///   all**. The user is sent to sign in the existing way first. Drawing the
///   button and relying on the API to refuse it would put the one control that
///   must never work on screen.
class LinkAccountPrompt extends ConsumerWidget {
  const LinkAccountPrompt({
    required this.decision,
    this.onContinueWithEmail,
    super.key,
  });

  final LinkDecision decision;
  final VoidCallback? onContinueWithEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final controller = ref.read(authControllerProvider.notifier);
    final decision = this.decision;

    return switch (decision) {
      LinkToExistingAccount(:final match) => _Prompt(
          title: l10n.signInLinkTitle,
          body: l10n.signInLinkBody(
            match.maskedEmail,
            _methodName(l10n, match.method),
          ),
          actionLabel: l10n.signInLinkConfirm,
          onAction: controller.confirmLink,
          onDismiss: controller.dismissLinkPrompt,
          dismissLabel: l10n.commonCancel,
        ),
      ProofOfControlRequired(:final match) => _Prompt(
          title: l10n.signInProofRequiredTitle,
          body: l10n.signInProofRequiredBody(
            match.maskedEmail,
            _methodName(l10n, match.method),
          ),
          actionLabel: l10n.signInWithEmail,
          onAction: () {
            controller.dismissLinkPrompt();
            onContinueWithEmail?.call();
          },
          onDismiss: controller.dismissLinkPrompt,
          dismissLabel: l10n.commonCancel,
        ),
      // Nothing to prompt about; the exchange already signed the user in.
      CreateNewAccount() => const SizedBox.shrink(),
    };
  }

  static String _methodName(AppL10n l10n, ExistingSignInMethod method) =>
      switch (method) {
        ExistingSignInMethod.password => l10n.providerNamePassword,
        ExistingSignInMethod.apple => l10n.providerNameApple,
        ExistingSignInMethod.google => l10n.providerNameGoogle,
      };
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style:
                  AppTypography.titleMedium.copyWith(color: colors.onSurface),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTypography.bodyMedium
                .copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: actionLabel,
            size: AppButtonSize.large,
            isFullWidth: true,
            onPressed: onAction,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: dismissLabel,
            variant: AppButtonVariant.tertiary,
            isFullWidth: true,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
