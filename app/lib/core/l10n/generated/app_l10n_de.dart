// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppL10nDe extends AppL10n {
  AppL10nDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Jyotish';

  @override
  String get commonLoading => 'Wird geladen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonRequiredField => 'Pflichtfeld';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String stepOfTotal(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String evaluationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Auswertungen',
      one: 'Eine Auswertung',
      zero: 'Keine Auswertungen',
    );
    return '$_temp0';
  }

  @override
  String daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Tage',
      one: 'Noch ein Tag',
      zero: 'Heute fällig',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemsprache';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get galleryTitle => 'Design System';

  @override
  String get gallerySectionColours => 'Farben';

  @override
  String get gallerySectionTypography => 'Typografie';

  @override
  String get gallerySectionButtons => 'Buttons';

  @override
  String get gallerySectionInputs => 'Eingaben';

  @override
  String get gallerySectionSelection => 'Auswahl';

  @override
  String get gallerySectionStatus => 'Status';

  @override
  String get gallerySectionContent => 'Inhalte';

  @override
  String get gallerySectionLoading => 'Ladezustände';

  @override
  String get gallerySectionEmpty => 'Leerzustände';

  @override
  String get gallerySectionOverlays => 'Overlays';

  @override
  String get gallerySectionFormatting => 'Formatierung';

  @override
  String get galleryThemeDark => 'Dunkles Design';

  @override
  String get galleryThemeLight => 'Helles Design';

  @override
  String orderCta(String price) {
    return 'Auswertung kostenpflichtig bestellen — $price';
  }

  @override
  String get fieldBirthPlace => 'Geburtsort';

  @override
  String get fieldBirthPlaceHint => 'z. B. München';

  @override
  String get fieldBirthPlaceHelper => 'Stadt und Land';

  @override
  String get fieldBirthTime => 'Geburtszeit';

  @override
  String get fieldBirthTimeError => 'Bitte eine gültige Uhrzeit eingeben';

  @override
  String get fieldBirthDate => 'Geburtsdatum';

  @override
  String get chartStyleNorth => 'Nord';

  @override
  String get chartStyleSouth => 'Süd';

  @override
  String get chartStyleWestern => 'Westlich';

  @override
  String get ayanamsaLabel => 'Ayanamsa';

  @override
  String get ayanamsaLahiriDescription => 'Chitrapaksha — Standard';

  @override
  String get houseSystemLabel => 'Haussystem';

  @override
  String get houseSystemWholeSign => 'Ganzzeichen';

  @override
  String get prefsDailyPanchang => 'Tägliches Panchang';

  @override
  String get prefsDailyPanchangDescription =>
      'Benachrichtigung jeden Morgen um 7 Uhr';

  @override
  String get consentWithdrawal =>
      'Ich stimme zu, dass die Auswertung sofort beginnt und mein Widerrufsrecht damit erlischt.';

  @override
  String get statusDraft => 'ENTWURF';

  @override
  String get statusPaid => 'BEZAHLT';

  @override
  String get statusInProgress => 'IN ARBEIT';

  @override
  String get statusSlaRisk => 'SLA-RISIKO';

  @override
  String get statusCancelled => 'STORNIERT';

  @override
  String get statusExpert => 'EXPERTE';

  @override
  String get bannerDeliveryTitle => 'Lieferfrist';

  @override
  String get bannerDeliveryMessage =>
      'Deine Auswertung wird in bis zu 72 Stunden geliefert.';

  @override
  String get bannerPaymentFailed =>
      'Zahlung fehlgeschlagen. Bitte Zahlungsart prüfen.';

  @override
  String get progressPdf => 'PDF wird erstellt';

  @override
  String get emptyChartTitle => 'Noch keine Kundali';

  @override
  String get emptyChartMessage =>
      'Lege deine Geburtsdaten an, um dein Chart zu sehen.';

  @override
  String get emptyChartAction => 'Geburtsdaten eingeben';

  @override
  String get errorGenericTitle => 'Etwas ist schiefgelaufen';

  @override
  String get errorEvaluationMessage =>
      'Die Auswertung konnte nicht geladen werden.';

  @override
  String get dialogCancelOrderTitle => 'Bestellung stornieren?';

  @override
  String get dialogCancelOrderMessage =>
      'Die Auswertung wird nicht erstellt und du erhältst den Betrag zurück.';

  @override
  String get dialogCancelOrderConfirm => 'Ja, stornieren';

  @override
  String get navChart => 'Kundali';

  @override
  String get navCareer => 'Karriere';

  @override
  String get navEvaluation => 'Auswertung';

  @override
  String get navProfile => 'Profil';

  @override
  String get labelAscendant => 'Aszendent';

  @override
  String get labelMoon => 'Mond';

  @override
  String get labelMahadasha => 'Mahadasha';

  @override
  String get labelPrice => 'Preis';

  @override
  String get labelOrderedAt => 'Bestellt am';

  @override
  String get labelDeliverBy => 'Lieferung bis';

  @override
  String get astrologerRole => 'Astrologin';

  @override
  String get snackSaved => 'Gespeichert.';

  @override
  String get snackDemoOnly => 'Nur eine Demo — es wurde nichts bestellt.';

  @override
  String get galleryDialogButton => 'Dialog';

  @override
  String get galleryBottomSheetButton => 'Bottom Sheet';

  @override
  String get gallerySnackbarButton => 'Snackbar';

  @override
  String get galleryButtonPrimary => 'Primär';

  @override
  String get galleryButtonSecondary => 'Sekundär';

  @override
  String get galleryButtonTertiary => 'Tertiär';

  @override
  String get galleryButtonDestructive => 'Löschen';

  @override
  String get galleryButtonDisabled => 'Deaktiviert';

  @override
  String get galleryButtonLoading => 'Lädt';

  @override
  String get galleryTabularFigures => 'Tabellenziffern';

  @override
  String get navHome => 'Start';

  @override
  String get placeholderNotBuilt => 'Dieser Bereich ist noch nicht gebaut.';

  @override
  String get offlineMessage =>
      'Keine Verbindung. Gespeicherte Kundalis kannst du weiterhin ansehen.';

  @override
  String evaluationOrderTitle(String orderId) {
    return 'Auswertung $orderId';
  }

  @override
  String get routeNotFoundTitle => 'Seite nicht gefunden';

  @override
  String routeNotFoundMessage(String location) {
    return 'Der Link $location führt nirgendwohin.';
  }

  @override
  String get routeNotFoundAction => 'Zur Startseite';

  @override
  String get profileDeveloperSection => 'Entwicklung';

  @override
  String get profileDesignGallerySubtitle => 'Komponenten und Farben ansehen';

  @override
  String get evaluationUnavailableTitle => 'Vorübergehend nicht verfügbar';

  @override
  String get evaluationUnavailableMessage =>
      'Expertenauswertungen können gerade nicht bestellt werden. Bitte versuche es später erneut.';
}
