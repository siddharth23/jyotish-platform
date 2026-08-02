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
}
