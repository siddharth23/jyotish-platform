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

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStart => 'Los geht\'s';

  @override
  String onboardingProgress(int current, int total) {
    return 'Seite $current von $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei Jyotish';

  @override
  String get onboardingWelcomeBody =>
      'Vedische Astrologie, sorgfältig berechnet und auf Deutsch erklärt.';

  @override
  String get onboardingChartTitle => 'Dein Kundali — kostenlos';

  @override
  String get onboardingChartBody =>
      'Gib deine Geburtsdaten ein und sieh dein vollständiges Geburtshoroskop mit Grahas, Häusern und Dashas. Ohne Kosten, ohne Konto.';

  @override
  String get onboardingCareerTitle => 'Berufliche Ausrichtung — kostenlos';

  @override
  String get onboardingCareerBody =>
      'Sieh, welche Branchen zu deinem Chart passen. Nur für dich persönlich, nicht für Arbeitgeber.';

  @override
  String onboardingExpertTitle(String price) {
    return 'Expertenauswertung — $price';
  }

  @override
  String get onboardingExpertBody =>
      'Eine persönliche Auswertung, geschrieben von einer echten Astrologin, als PDF innerhalb von 72 Stunden. Optional und jederzeit.';

  @override
  String get signInTitle => 'Anmelden';

  @override
  String get signInBody =>
      'Melde dich an, um deine Kundalis und Auswertungen zu sichern.';

  @override
  String get signInWithApple => 'Mit Apple anmelden';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get signInWithEmail => 'Mit E-Mail-Adresse fortfahren';

  @override
  String get signInDivider => 'oder';

  @override
  String get signInSocialUnavailable =>
      'Anmeldung über Apple oder Google ist auf diesem Gerät gerade nicht möglich.';

  @override
  String get signInPrivateRelayTitle => 'Deine Adresse bleibt verborgen';

  @override
  String get signInPrivateRelayBody =>
      'Apple leitet E-Mails an dich weiter, ohne uns deine Adresse zu zeigen. Deine Auswertung kommt per E-Mail — wenn du die Weiterleitung später abschaltest, erreicht sie dich nicht mehr.';

  @override
  String get signInLinkTitle => 'Konto verknüpfen?';

  @override
  String signInLinkBody(String email, String provider) {
    return 'Für $email gibt es bereits ein Konto. Möchtest du es mit $provider verknüpfen? Deine Kundalis und Bestellungen bleiben erhalten.';
  }

  @override
  String get signInLinkConfirm => 'Verknüpfen';

  @override
  String get signInProofRequiredTitle => 'Bitte zuerst anmelden';

  @override
  String signInProofRequiredBody(String email, String provider) {
    return 'Für $email gibt es bereits ein Konto. Melde dich zuerst wie gewohnt an — dann können wir $provider sicher hinzufügen.';
  }

  @override
  String get signInErrorNetwork =>
      'Keine Verbindung. Bitte versuche es erneut.';

  @override
  String get signInErrorProviderUnavailable =>
      'Diese Anmeldung ist auf diesem Gerät nicht verfügbar.';

  @override
  String get signInErrorTokenRejected =>
      'Die Anmeldung konnte nicht bestätigt werden. Bitte versuche es erneut.';

  @override
  String get signInErrorNotImplemented =>
      'Diese Anmeldung ist noch nicht verfügbar.';

  @override
  String get signInErrorUnknown =>
      'Die Anmeldung hat nicht geklappt. Bitte versuche es erneut.';

  @override
  String get providerNameApple => 'Apple';

  @override
  String get providerNameGoogle => 'Google';

  @override
  String get providerNamePassword => 'E-Mail und Passwort';

  @override
  String get accountSectionTitle => 'Konto';

  @override
  String get accountDelete => 'Konto löschen';

  @override
  String get accountDeleteSubtitle => 'Dauerhaft und unwiderruflich';

  @override
  String get deleteAccountTitle => 'Konto löschen';

  @override
  String get deleteAccountIntro =>
      'Dein Konto wird sofort gesperrt. Sieben Tage später werden deine Daten endgültig gelöscht.';

  @override
  String get deleteAccountErasedHeading => 'Was gelöscht wird';

  @override
  String get deleteAccountRetainedHeading => 'Was wir behalten müssen';

  @override
  String get deleteAccountErasedBirthData =>
      'Geburtsdaten und gespeicherte Personen';

  @override
  String get deleteAccountErasedCharts => 'Kundalis und Auswertungen';

  @override
  String get deleteAccountErasedCareer => 'Karriereanalysen';

  @override
  String get deleteAccountErasedAccount =>
      'E-Mail-Adresse, Passwort und Anmeldungen';

  @override
  String get deleteAccountRetainedInvoices =>
      'Rechnungen zu bezahlten Auswertungen. Das deutsche Steuerrecht (§ 147 AO) verpflichtet uns, sie zehn Jahre lang aufzubewahren. Sie enthalten nur die gesetzlich vorgeschriebenen Angaben.';

  @override
  String deleteAccountPurgeDate(String date) {
    return 'Endgültige Löschung am $date';
  }

  @override
  String get deleteAccountCancelHint =>
      'Bis dahin kannst du die Löschung rückgängig machen, indem du dich wieder anmeldest.';

  @override
  String get deleteAccountCta => 'Konto endgültig löschen';

  @override
  String get deleteAccountDialogTitle => 'Konto wirklich löschen?';

  @override
  String get deleteAccountDialogMessage =>
      'Deine Geburtsdaten, Kundalis und Auswertungen werden gelöscht. Rechnungen müssen wir aus steuerrechtlichen Gründen behalten.';

  @override
  String get deleteAccountDialogConfirm => 'Ja, Konto löschen';

  @override
  String get deleteAccountScheduled =>
      'Dein Konto wurde zur Löschung vorgemerkt.';

  @override
  String get deleteAccountFailed =>
      'Die Löschung konnte nicht angefordert werden. Bitte versuche es später erneut.';

  @override
  String get birthDataTitle => 'Geburtsdaten';

  @override
  String get birthDataIntro =>
      'Für ein genaues Kundali brauchen wir Datum und Uhrzeit deiner Geburt.';

  @override
  String get birthDateLabel => 'Geburtsdatum';

  @override
  String get birthDateHint => 'TT.MM.JJJJ';

  @override
  String get birthTimeLabel => 'Geburtszeit';

  @override
  String get birthTimeHint => 'HH:MM';

  @override
  String get birthTimeHelper =>
      '24-Stunden-Format, zum Beispiel 07:30 oder 19:45';

  @override
  String get birthTimeUnknownLabel => 'Geburtszeit unbekannt';

  @override
  String get birthTimeWhyItMattersTitle => 'Warum die genaue Minute zählt';

  @override
  String get birthTimeWhyItMatters =>
      'Der Aszendent verschiebt sich etwa alle vier Minuten um ein Grad und kann innerhalb einer Stunde in ein anderes Zeichen wechseln. Er bestimmt die Häuser — und damit fast jede Aussage zu Beruf, Partnerschaft und Zeitpunkten. Steht die Uhrzeit auf deiner Geburtsurkunde, nimm diese.';

  @override
  String get birthTimeUnknownCaveatTitle => 'Ohne Uhrzeit: Sonnenhoroskop';

  @override
  String get birthTimeUnknownCaveat =>
      'Ohne Geburtszeit gibt es keinen Aszendenten und damit keine Häuser. Wir berechnen ein Sonnenhoroskop: Planetenstände und Dashas stimmen, Aussagen zu Beruf, Partnerschaft und Zeitpunkten sind aber nur eingeschränkt möglich.';

  @override
  String get birthDateErrorMalformed => 'Bitte im Format TT.MM.JJJJ eingeben';

  @override
  String get birthDateErrorNotACalendarDate => 'Dieses Datum gibt es nicht';

  @override
  String get birthDateErrorInFuture =>
      'Das Geburtsdatum kann nicht in der Zukunft liegen';

  @override
  String get birthDateErrorTooEarly => 'Bitte ein Jahr ab 1800 eingeben';

  @override
  String get birthTimeErrorMalformed =>
      'Bitte im Format HH:MM eingeben, zum Beispiel 19:45';

  @override
  String get birthTimeErrorOutOfRange =>
      'Bitte eine Uhrzeit zwischen 00:00 und 23:59 eingeben';

  @override
  String get birthDataContinue => 'Weiter';
}
