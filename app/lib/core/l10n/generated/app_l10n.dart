import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_de.dart';
import 'app_l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// Product name. Not translated — it is the brand.
  ///
  /// In de, this message translates to:
  /// **'Jyotish'**
  String get appTitle;

  /// Announced by screen readers while a control is busy.
  ///
  /// In de, this message translates to:
  /// **'Wird geladen'**
  String get commonLoading;

  /// Label for a control that dismisses a sheet or dialog.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get commonClose;

  /// No description provided for @commonCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get commonRetry;

  /// Announced for the asterisk beside a required input label.
  ///
  /// In de, this message translates to:
  /// **'Pflichtfeld'**
  String get commonRequiredField;

  /// No description provided for @commonRemove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get commonRemove;

  /// Position within a multi-step flow.
  ///
  /// In de, this message translates to:
  /// **'Schritt {current} von {total}'**
  String stepOfTotal(int current, int total);

  /// Number of expert evaluations. German has no separate dual form, but the zero case reads better as a word than as '0'.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Auswertungen} =1{Eine Auswertung} other{{count} Auswertungen}}'**
  String evaluationCount(int count);

  /// Time left before the 72-hour delivery SLA expires.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Heute fällig} =1{Noch ein Tag} other{Noch {count} Tage}}'**
  String daysRemaining(int count);

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// Follow the device locale rather than an explicit choice.
  ///
  /// In de, this message translates to:
  /// **'Systemsprache'**
  String get settingsLanguageSystem;

  /// Always written in German, in every locale — a language list shows each language in its own name.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageGerman;

  /// Always written in English, in every locale.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @galleryTitle.
  ///
  /// In de, this message translates to:
  /// **'Design System'**
  String get galleryTitle;

  /// No description provided for @gallerySectionColours.
  ///
  /// In de, this message translates to:
  /// **'Farben'**
  String get gallerySectionColours;

  /// No description provided for @gallerySectionTypography.
  ///
  /// In de, this message translates to:
  /// **'Typografie'**
  String get gallerySectionTypography;

  /// No description provided for @gallerySectionButtons.
  ///
  /// In de, this message translates to:
  /// **'Buttons'**
  String get gallerySectionButtons;

  /// No description provided for @gallerySectionInputs.
  ///
  /// In de, this message translates to:
  /// **'Eingaben'**
  String get gallerySectionInputs;

  /// No description provided for @gallerySectionSelection.
  ///
  /// In de, this message translates to:
  /// **'Auswahl'**
  String get gallerySectionSelection;

  /// No description provided for @gallerySectionStatus.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get gallerySectionStatus;

  /// No description provided for @gallerySectionContent.
  ///
  /// In de, this message translates to:
  /// **'Inhalte'**
  String get gallerySectionContent;

  /// No description provided for @gallerySectionLoading.
  ///
  /// In de, this message translates to:
  /// **'Ladezustände'**
  String get gallerySectionLoading;

  /// No description provided for @gallerySectionEmpty.
  ///
  /// In de, this message translates to:
  /// **'Leerzustände'**
  String get gallerySectionEmpty;

  /// No description provided for @gallerySectionOverlays.
  ///
  /// In de, this message translates to:
  /// **'Overlays'**
  String get gallerySectionOverlays;

  /// No description provided for @gallerySectionFormatting.
  ///
  /// In de, this message translates to:
  /// **'Formatierung'**
  String get gallerySectionFormatting;

  /// No description provided for @galleryThemeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkles Design'**
  String get galleryThemeDark;

  /// No description provided for @galleryThemeLight.
  ///
  /// In de, this message translates to:
  /// **'Helles Design'**
  String get galleryThemeLight;

  /// Primary paid action. The price is formatted for the active locale.
  ///
  /// In de, this message translates to:
  /// **'Auswertung kostenpflichtig bestellen — {price}'**
  String orderCta(String price);

  /// No description provided for @fieldBirthPlace.
  ///
  /// In de, this message translates to:
  /// **'Geburtsort'**
  String get fieldBirthPlace;

  /// No description provided for @fieldBirthPlaceHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. München'**
  String get fieldBirthPlaceHint;

  /// No description provided for @fieldBirthPlaceHelper.
  ///
  /// In de, this message translates to:
  /// **'Stadt und Land'**
  String get fieldBirthPlaceHelper;

  /// No description provided for @fieldBirthTime.
  ///
  /// In de, this message translates to:
  /// **'Geburtszeit'**
  String get fieldBirthTime;

  /// No description provided for @fieldBirthTimeError.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine gültige Uhrzeit eingeben'**
  String get fieldBirthTimeError;

  /// No description provided for @fieldBirthDate.
  ///
  /// In de, this message translates to:
  /// **'Geburtsdatum'**
  String get fieldBirthDate;

  /// No description provided for @chartStyleNorth.
  ///
  /// In de, this message translates to:
  /// **'Nord'**
  String get chartStyleNorth;

  /// No description provided for @chartStyleSouth.
  ///
  /// In de, this message translates to:
  /// **'Süd'**
  String get chartStyleSouth;

  /// No description provided for @chartStyleWestern.
  ///
  /// In de, this message translates to:
  /// **'Westlich'**
  String get chartStyleWestern;

  /// No description provided for @ayanamsaLabel.
  ///
  /// In de, this message translates to:
  /// **'Ayanamsa'**
  String get ayanamsaLabel;

  /// No description provided for @ayanamsaLahiriDescription.
  ///
  /// In de, this message translates to:
  /// **'Chitrapaksha — Standard'**
  String get ayanamsaLahiriDescription;

  /// No description provided for @houseSystemLabel.
  ///
  /// In de, this message translates to:
  /// **'Haussystem'**
  String get houseSystemLabel;

  /// No description provided for @houseSystemWholeSign.
  ///
  /// In de, this message translates to:
  /// **'Ganzzeichen'**
  String get houseSystemWholeSign;

  /// No description provided for @prefsDailyPanchang.
  ///
  /// In de, this message translates to:
  /// **'Tägliches Panchang'**
  String get prefsDailyPanchang;

  /// No description provided for @prefsDailyPanchangDescription.
  ///
  /// In de, this message translates to:
  /// **'Benachrichtigung jeden Morgen um 7 Uhr'**
  String get prefsDailyPanchangDescription;

  /// Checkout consent. Wording is legally load-bearing — do not paraphrase without a lawyer.
  ///
  /// In de, this message translates to:
  /// **'Ich stimme zu, dass die Auswertung sofort beginnt und mein Widerrufsrecht damit erlischt.'**
  String get consentWithdrawal;

  /// No description provided for @statusDraft.
  ///
  /// In de, this message translates to:
  /// **'ENTWURF'**
  String get statusDraft;

  /// No description provided for @statusPaid.
  ///
  /// In de, this message translates to:
  /// **'BEZAHLT'**
  String get statusPaid;

  /// No description provided for @statusInProgress.
  ///
  /// In de, this message translates to:
  /// **'IN ARBEIT'**
  String get statusInProgress;

  /// No description provided for @statusSlaRisk.
  ///
  /// In de, this message translates to:
  /// **'SLA-RISIKO'**
  String get statusSlaRisk;

  /// No description provided for @statusCancelled.
  ///
  /// In de, this message translates to:
  /// **'STORNIERT'**
  String get statusCancelled;

  /// No description provided for @statusExpert.
  ///
  /// In de, this message translates to:
  /// **'EXPERTE'**
  String get statusExpert;

  /// No description provided for @bannerDeliveryTitle.
  ///
  /// In de, this message translates to:
  /// **'Lieferfrist'**
  String get bannerDeliveryTitle;

  /// No description provided for @bannerDeliveryMessage.
  ///
  /// In de, this message translates to:
  /// **'Deine Auswertung wird in bis zu 72 Stunden geliefert.'**
  String get bannerDeliveryMessage;

  /// No description provided for @bannerPaymentFailed.
  ///
  /// In de, this message translates to:
  /// **'Zahlung fehlgeschlagen. Bitte Zahlungsart prüfen.'**
  String get bannerPaymentFailed;

  /// No description provided for @progressPdf.
  ///
  /// In de, this message translates to:
  /// **'PDF wird erstellt'**
  String get progressPdf;

  /// No description provided for @emptyChartTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Kundali'**
  String get emptyChartTitle;

  /// No description provided for @emptyChartMessage.
  ///
  /// In de, this message translates to:
  /// **'Lege deine Geburtsdaten an, um dein Chart zu sehen.'**
  String get emptyChartMessage;

  /// No description provided for @emptyChartAction.
  ///
  /// In de, this message translates to:
  /// **'Geburtsdaten eingeben'**
  String get emptyChartAction;

  /// No description provided for @errorGenericTitle.
  ///
  /// In de, this message translates to:
  /// **'Etwas ist schiefgelaufen'**
  String get errorGenericTitle;

  /// No description provided for @errorEvaluationMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Auswertung konnte nicht geladen werden.'**
  String get errorEvaluationMessage;

  /// No description provided for @dialogCancelOrderTitle.
  ///
  /// In de, this message translates to:
  /// **'Bestellung stornieren?'**
  String get dialogCancelOrderTitle;

  /// No description provided for @dialogCancelOrderMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Auswertung wird nicht erstellt und du erhältst den Betrag zurück.'**
  String get dialogCancelOrderMessage;

  /// No description provided for @dialogCancelOrderConfirm.
  ///
  /// In de, this message translates to:
  /// **'Ja, stornieren'**
  String get dialogCancelOrderConfirm;

  /// No description provided for @navChart.
  ///
  /// In de, this message translates to:
  /// **'Kundali'**
  String get navChart;

  /// No description provided for @navCareer.
  ///
  /// In de, this message translates to:
  /// **'Karriere'**
  String get navCareer;

  /// No description provided for @navEvaluation.
  ///
  /// In de, this message translates to:
  /// **'Auswertung'**
  String get navEvaluation;

  /// No description provided for @navProfile.
  ///
  /// In de, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @labelAscendant.
  ///
  /// In de, this message translates to:
  /// **'Aszendent'**
  String get labelAscendant;

  /// No description provided for @labelMoon.
  ///
  /// In de, this message translates to:
  /// **'Mond'**
  String get labelMoon;

  /// No description provided for @labelMahadasha.
  ///
  /// In de, this message translates to:
  /// **'Mahadasha'**
  String get labelMahadasha;

  /// No description provided for @labelPrice.
  ///
  /// In de, this message translates to:
  /// **'Preis'**
  String get labelPrice;

  /// No description provided for @labelOrderedAt.
  ///
  /// In de, this message translates to:
  /// **'Bestellt am'**
  String get labelOrderedAt;

  /// No description provided for @labelDeliverBy.
  ///
  /// In de, this message translates to:
  /// **'Lieferung bis'**
  String get labelDeliverBy;

  /// Feminine form, for the sample astrologer in the gallery. Real screens must pick the form matching the person.
  ///
  /// In de, this message translates to:
  /// **'Astrologin'**
  String get astrologerRole;

  /// No description provided for @snackSaved.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert.'**
  String get snackSaved;

  /// No description provided for @snackDemoOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur eine Demo — es wurde nichts bestellt.'**
  String get snackDemoOnly;

  /// No description provided for @galleryDialogButton.
  ///
  /// In de, this message translates to:
  /// **'Dialog'**
  String get galleryDialogButton;

  /// No description provided for @galleryBottomSheetButton.
  ///
  /// In de, this message translates to:
  /// **'Bottom Sheet'**
  String get galleryBottomSheetButton;

  /// No description provided for @gallerySnackbarButton.
  ///
  /// In de, this message translates to:
  /// **'Snackbar'**
  String get gallerySnackbarButton;

  /// No description provided for @galleryButtonPrimary.
  ///
  /// In de, this message translates to:
  /// **'Primär'**
  String get galleryButtonPrimary;

  /// No description provided for @galleryButtonSecondary.
  ///
  /// In de, this message translates to:
  /// **'Sekundär'**
  String get galleryButtonSecondary;

  /// No description provided for @galleryButtonTertiary.
  ///
  /// In de, this message translates to:
  /// **'Tertiär'**
  String get galleryButtonTertiary;

  /// No description provided for @galleryButtonDestructive.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get galleryButtonDestructive;

  /// No description provided for @galleryButtonDisabled.
  ///
  /// In de, this message translates to:
  /// **'Deaktiviert'**
  String get galleryButtonDisabled;

  /// No description provided for @galleryButtonLoading.
  ///
  /// In de, this message translates to:
  /// **'Lädt'**
  String get galleryButtonLoading;

  /// No description provided for @galleryTabularFigures.
  ///
  /// In de, this message translates to:
  /// **'Tabellenziffern'**
  String get galleryTabularFigures;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppL10nDe();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
