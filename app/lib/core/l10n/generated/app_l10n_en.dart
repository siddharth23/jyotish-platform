// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jyotish';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonRequiredField => 'Required field';

  @override
  String get commonRemove => 'Remove';

  @override
  String stepOfTotal(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String evaluationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evaluations',
      one: 'One evaluation',
      zero: 'No evaluations',
    );
    return '$_temp0';
  }

  @override
  String daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: 'One day left',
      zero: 'Due today',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System language';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get galleryTitle => 'Design system';

  @override
  String get gallerySectionColours => 'Colours';

  @override
  String get gallerySectionTypography => 'Typography';

  @override
  String get gallerySectionButtons => 'Buttons';

  @override
  String get gallerySectionInputs => 'Inputs';

  @override
  String get gallerySectionSelection => 'Selection';

  @override
  String get gallerySectionStatus => 'Status';

  @override
  String get gallerySectionContent => 'Content';

  @override
  String get gallerySectionLoading => 'Loading states';

  @override
  String get gallerySectionEmpty => 'Empty states';

  @override
  String get gallerySectionOverlays => 'Overlays';

  @override
  String get gallerySectionFormatting => 'Formatting';

  @override
  String get galleryThemeDark => 'Dark theme';

  @override
  String get galleryThemeLight => 'Light theme';

  @override
  String orderCta(String price) {
    return 'Order expert evaluation — $price';
  }

  @override
  String get fieldBirthPlace => 'Place of birth';

  @override
  String get fieldBirthPlaceHint => 'e.g. Munich';

  @override
  String get fieldBirthPlaceHelper => 'City and country';

  @override
  String get fieldBirthTime => 'Time of birth';

  @override
  String get fieldBirthTimeError => 'Please enter a valid time';

  @override
  String get fieldBirthDate => 'Date of birth';

  @override
  String get chartStyleNorth => 'North';

  @override
  String get chartStyleSouth => 'South';

  @override
  String get chartStyleWestern => 'Western';

  @override
  String get ayanamsaLabel => 'Ayanamsa';

  @override
  String get ayanamsaLahiriDescription => 'Chitrapaksha — default';

  @override
  String get houseSystemLabel => 'House system';

  @override
  String get houseSystemWholeSign => 'Whole sign';

  @override
  String get prefsDailyPanchang => 'Daily panchang';

  @override
  String get prefsDailyPanchangDescription =>
      'A notification every morning at 7 am';

  @override
  String get consentWithdrawal =>
      'I agree that work begins immediately and that my right of withdrawal thereby lapses.';

  @override
  String get statusDraft => 'DRAFT';

  @override
  String get statusPaid => 'PAID';

  @override
  String get statusInProgress => 'IN PROGRESS';

  @override
  String get statusSlaRisk => 'SLA RISK';

  @override
  String get statusCancelled => 'CANCELLED';

  @override
  String get statusExpert => 'EXPERT';

  @override
  String get bannerDeliveryTitle => 'Delivery time';

  @override
  String get bannerDeliveryMessage =>
      'Your evaluation will be delivered within 72 hours.';

  @override
  String get bannerPaymentFailed =>
      'Payment failed. Please check your payment method.';

  @override
  String get progressPdf => 'Generating PDF';

  @override
  String get emptyChartTitle => 'No kundali yet';

  @override
  String get emptyChartMessage => 'Add your birth details to see your chart.';

  @override
  String get emptyChartAction => 'Enter birth details';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorEvaluationMessage => 'The evaluation could not be loaded.';

  @override
  String get dialogCancelOrderTitle => 'Cancel this order?';

  @override
  String get dialogCancelOrderMessage =>
      'The evaluation will not be produced and you will be refunded.';

  @override
  String get dialogCancelOrderConfirm => 'Yes, cancel it';

  @override
  String get navChart => 'Kundali';

  @override
  String get navCareer => 'Career';

  @override
  String get navEvaluation => 'Evaluation';

  @override
  String get navProfile => 'Profile';

  @override
  String get labelAscendant => 'Ascendant';

  @override
  String get labelMoon => 'Moon';

  @override
  String get labelMahadasha => 'Mahadasha';

  @override
  String get labelPrice => 'Price';

  @override
  String get labelOrderedAt => 'Ordered on';

  @override
  String get labelDeliverBy => 'Deliver by';

  @override
  String get astrologerRole => 'Astrologer';

  @override
  String get snackSaved => 'Saved.';

  @override
  String get snackDemoOnly => 'Demo only — nothing was ordered.';

  @override
  String get galleryDialogButton => 'Dialog';

  @override
  String get galleryBottomSheetButton => 'Bottom sheet';

  @override
  String get gallerySnackbarButton => 'Snackbar';

  @override
  String get galleryButtonPrimary => 'Primary';

  @override
  String get galleryButtonSecondary => 'Secondary';

  @override
  String get galleryButtonTertiary => 'Tertiary';

  @override
  String get galleryButtonDestructive => 'Delete';

  @override
  String get galleryButtonDisabled => 'Disabled';

  @override
  String get galleryButtonLoading => 'Loading';

  @override
  String get galleryTabularFigures => 'Tabular figures';

  @override
  String get navHome => 'Home';

  @override
  String get placeholderNotBuilt => 'This section has not been built yet.';

  @override
  String get offlineMessage =>
      'No connection. You can still view saved kundalis.';

  @override
  String evaluationOrderTitle(String orderId) {
    return 'Evaluation $orderId';
  }

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String routeNotFoundMessage(String location) {
    return 'The link $location does not go anywhere.';
  }

  @override
  String get routeNotFoundAction => 'Go to start';

  @override
  String get profileDeveloperSection => 'Development';

  @override
  String get profileDesignGallerySubtitle => 'Browse components and colours';

  @override
  String get evaluationUnavailableTitle => 'Temporarily unavailable';

  @override
  String get evaluationUnavailableMessage =>
      'Expert evaluations cannot be ordered right now. Please try again later.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String onboardingProgress(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Welcome to Jyotish';

  @override
  String get onboardingWelcomeBody =>
      'Vedic astrology, carefully calculated and clearly explained.';

  @override
  String get onboardingChartTitle => 'Your kundali — free';

  @override
  String get onboardingChartBody =>
      'Enter your birth details and see your full birth chart with grahas, houses and dashas. No cost, no account.';

  @override
  String get onboardingCareerTitle => 'Career fit — free';

  @override
  String get onboardingCareerBody =>
      'See which industries suit your chart. For you personally, never for employers.';

  @override
  String onboardingExpertTitle(String price) {
    return 'Expert evaluation — $price';
  }

  @override
  String get onboardingExpertBody =>
      'A personal reading written by a real astrologer, delivered as a PDF within 72 hours. Optional, whenever you want it.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInBody => 'Sign in to keep your kundalis and evaluations.';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithEmail => 'Continue with email';

  @override
  String get signInDivider => 'or';

  @override
  String get signInSocialUnavailable =>
      'Signing in with Apple or Google is not available on this device right now.';

  @override
  String get signInPrivateRelayTitle => 'Your address stays hidden';

  @override
  String get signInPrivateRelayBody =>
      'Apple forwards email to you without showing us your address. Your evaluation arrives by email — if you turn forwarding off later, it will not reach you.';

  @override
  String get signInLinkTitle => 'Link this account?';

  @override
  String signInLinkBody(String email, String provider) {
    return 'An account already exists for $email. Link it with $provider? Your kundalis and orders are kept.';
  }

  @override
  String get signInLinkConfirm => 'Link';

  @override
  String get signInProofRequiredTitle => 'Please sign in first';

  @override
  String signInProofRequiredBody(String email, String provider) {
    return 'An account already exists for $email. Sign in the usual way first, then we can add $provider safely.';
  }

  @override
  String get signInErrorNetwork => 'No connection. Please try again.';

  @override
  String get signInErrorProviderUnavailable =>
      'This sign-in method is not available on this device.';

  @override
  String get signInErrorTokenRejected =>
      'We could not confirm the sign-in. Please try again.';

  @override
  String get signInErrorNotImplemented =>
      'This sign-in method is not available yet.';

  @override
  String get signInErrorUnknown => 'Sign-in did not work. Please try again.';

  @override
  String get providerNameApple => 'Apple';

  @override
  String get providerNameGoogle => 'Google';

  @override
  String get providerNamePassword => 'Email and password';

  @override
  String get accountSectionTitle => 'Account';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteSubtitle => 'Permanent and irreversible';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountIntro =>
      'Your account is locked immediately. Seven days later your data is permanently erased.';

  @override
  String get deleteAccountErasedHeading => 'What is deleted';

  @override
  String get deleteAccountRetainedHeading => 'What we are required to keep';

  @override
  String get deleteAccountErasedBirthData => 'Birth details and saved people';

  @override
  String get deleteAccountErasedCharts => 'Kundalis and evaluations';

  @override
  String get deleteAccountErasedCareer => 'Career analyses';

  @override
  String get deleteAccountErasedAccount =>
      'Email address, password and sign-ins';

  @override
  String get deleteAccountRetainedInvoices =>
      'Invoices for evaluations you paid for. German tax law (§ 147 AO) requires us to keep them for ten years. They contain only the legally required details.';

  @override
  String deleteAccountPurgeDate(String date) {
    return 'Final deletion on $date';
  }

  @override
  String get deleteAccountCancelHint =>
      'Until then you can undo the deletion by signing in again.';

  @override
  String get deleteAccountCta => 'Permanently delete account';

  @override
  String get deleteAccountDialogTitle => 'Really delete your account?';

  @override
  String get deleteAccountDialogMessage =>
      'Your birth details, kundalis and evaluations will be deleted. We must keep invoices for tax reasons.';

  @override
  String get deleteAccountDialogConfirm => 'Yes, delete it';

  @override
  String get deleteAccountScheduled =>
      'Your account is scheduled for deletion.';

  @override
  String get deleteAccountFailed =>
      'The deletion could not be requested. Please try again later.';

  @override
  String get birthDataTitle => 'Birth details';

  @override
  String get birthDataIntro =>
      'For an accurate kundali we need the date and time of your birth.';

  @override
  String get birthDateLabel => 'Date of birth';

  @override
  String get birthDateHint => 'DD.MM.YYYY';

  @override
  String get birthTimeLabel => 'Time of birth';

  @override
  String get birthTimeHint => 'HH:MM';

  @override
  String get birthTimeHelper => '24-hour format, for example 07:30 or 19:45';

  @override
  String get birthTimeUnknownLabel => 'Time of birth unknown';

  @override
  String get birthTimeWhyItMattersTitle => 'Why the exact minute matters';

  @override
  String get birthTimeWhyItMatters =>
      'The ascendant moves about one degree every four minutes and can change sign within an hour. It sets the houses — and with them almost everything about career, relationships and timing. If your birth certificate gives a time, use that one.';

  @override
  String get birthTimeUnknownCaveatTitle => 'Without a time: solar chart';

  @override
  String get birthTimeUnknownCaveat =>
      'Without a birth time there is no ascendant, and therefore no houses. We calculate a solar chart: planetary positions and dashas are correct, but statements about career, relationships and timing are only partly possible.';

  @override
  String get birthDateErrorMalformed => 'Please enter it as DD.MM.YYYY';

  @override
  String get birthDateErrorNotACalendarDate => 'That date does not exist';

  @override
  String get birthDateErrorInFuture =>
      'The date of birth cannot be in the future';

  @override
  String get birthDateErrorTooEarly => 'Please enter a year from 1800 onwards';

  @override
  String get birthTimeErrorMalformed =>
      'Please enter it as HH:MM, for example 19:45';

  @override
  String get birthTimeErrorOutOfRange =>
      'Please enter a time between 00:00 and 23:59';

  @override
  String get birthDataContinue => 'Continue';
}
