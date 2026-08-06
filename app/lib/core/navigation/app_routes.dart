/// Every route path in the app, in one place.
///
/// These strings are part of the app's public surface: they appear in deep
/// links, in push-notification payloads and in emails. **Changing one breaks
/// every link already sent**, including the delivery notification for an
/// evaluation someone paid for. Add a redirect rather than renaming.
abstract final class AppRoutes {
  static const String home = '/';
  static const String chart = '/kundali';
  static const String career = '/karriere';
  static const String evaluation = '/auswertung';
  static const String profile = '/profil';

  /// A single evaluation, as linked from its delivery email.
  static const String evaluationDetail = '/auswertung/:orderId';

  /// Sign-in. Reachable by URL so it can be opened on a device during review,
  /// and the destination US-013's checkout gate pushes to. Nothing links to it
  /// yet: there is no flow that requires an account until then.
  static const String signIn = '/anmelden';

  /// First-run onboarding. Not deep-linkable from outside the app; it is
  /// reached by redirect, and left by completing it.
  static const String onboarding = '/onboarding';

  /// The design system gallery. Not product surface — reachable by URL so it can
  /// be opened on a device during review, but not linked from any screen.
  static const String designGallery = '/design';

  static String evaluationFor(String orderId) => '/auswertung/$orderId';

  /// Paths the bottom bar switches between, in tab order.
  static const List<String> tabs = [home, chart, career, evaluation, profile];
}
