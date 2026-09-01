import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lector Sport'**
  String get appTitle;

  /// No description provided for @onboardingEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'COPILOT — MISE EN ROUTE'**
  String get onboardingEyebrow;

  /// No description provided for @onboardingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Construisons votre profil de décision'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas un profil marketing. Une carte de votre façon de réfléchir.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingQuestionProgress.
  ///
  /// In fr, this message translates to:
  /// **'QUESTION {current} / {total}'**
  String onboardingQuestionProgress(int current, int total);

  /// No description provided for @nextButton.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get nextButton;

  /// No description provided for @backButton.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get backButton;

  /// No description provided for @cancelButton.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancelButton;

  /// No description provided for @skipOnboardingButton.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get skipOnboardingButton;

  /// No description provided for @skipOnboardingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser une configuration par défaut ?'**
  String get skipOnboardingTitle;

  /// No description provided for @skipOnboardingMessage.
  ///
  /// In fr, this message translates to:
  /// **'Sans onboarding, Lector appliquera une configuration générale qui ne sera pas personnalisée à votre manière de décider.'**
  String get skipOnboardingMessage;

  /// No description provided for @keepOnboardingButton.
  ///
  /// In fr, this message translates to:
  /// **'Continuer l’onboarding'**
  String get keepOnboardingButton;

  /// No description provided for @useDefaultProfileButton.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le profil par défaut'**
  String get useDefaultProfileButton;

  /// No description provided for @reviewProfileButton.
  ///
  /// In fr, this message translates to:
  /// **'Voir mon profil'**
  String get reviewProfileButton;

  /// No description provided for @selectedOptionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélection priorisée'**
  String get selectedOptionsTitle;

  /// No description provided for @availableOptionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Options disponibles'**
  String get availableOptionsTitle;

  /// No description provided for @removeOptionTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get removeOptionTooltip;

  /// No description provided for @minOddsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Min.'**
  String get minOddsLabel;

  /// No description provided for @maxOddsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Max.'**
  String get maxOddsLabel;

  /// No description provided for @noSelectedMarketsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun marché favori sélectionné.'**
  String get noSelectedMarketsMessage;

  /// No description provided for @noSelectionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sélection'**
  String get noSelectionLabel;

  /// No description provided for @moreValuesLabel.
  ///
  /// In fr, this message translates to:
  /// **'+ {count} autres'**
  String moreValuesLabel(int count);

  /// No description provided for @profileSummaryEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'PROFIL DE DÉCISION'**
  String get profileSummaryEyebrow;

  /// No description provided for @profileSummaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil'**
  String get profileSummaryTitle;

  /// No description provided for @profileSummarySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez que Lector a correctement compris votre manière de décider.'**
  String get profileSummarySubtitle;

  /// No description provided for @confirmProfileButton.
  ///
  /// In fr, this message translates to:
  /// **'Valider et voir les matchs'**
  String get confirmProfileButton;

  /// No description provided for @savedProfileDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil sauvegardé'**
  String get savedProfileDialogTitle;

  /// No description provided for @savedProfileDialogMessage.
  ///
  /// In fr, this message translates to:
  /// **'Un profil de décision existe déjà sur cet appareil. Voulez-vous l’utiliser pour cette session de développement ?'**
  String get savedProfileDialogMessage;

  /// No description provided for @savedProfileUseButton.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ce profil'**
  String get savedProfileUseButton;

  /// No description provided for @savedProfileRedoButton.
  ///
  /// In fr, this message translates to:
  /// **'Refaire l’onboarding'**
  String get savedProfileRedoButton;

  /// No description provided for @homeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get homeTitle;

  /// No description provided for @editProfileTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil'**
  String get editProfileTooltip;

  /// No description provided for @profileSettingsButton.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil'**
  String get profileSettingsButton;

  /// No description provided for @forMeTab.
  ///
  /// In fr, this message translates to:
  /// **'Pour moi'**
  String get forMeTab;

  /// No description provided for @allMatchesTab.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les rencontres'**
  String get allMatchesTab;

  /// No description provided for @forMeHeading.
  ///
  /// In fr, this message translates to:
  /// **'{count} rencontres pour votre profil'**
  String forMeHeading(int count);

  /// No description provided for @forMeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ces rencontres sont affichées selon les priorités de votre profil. Le moteur reste séparé de l’interface.'**
  String get forMeSubtitle;

  /// No description provided for @allMatchesHeading.
  ///
  /// In fr, this message translates to:
  /// **'{count} rencontres disponibles'**
  String allMatchesHeading(int count);

  /// No description provided for @allMatchesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rencontre n’est masquée. Lector priorise, il ne supprime pas.'**
  String get allMatchesSubtitle;

  /// No description provided for @championshipsByCountryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Championnats par pays'**
  String get championshipsByCountryTitle;

  /// No description provided for @championshipsByCountrySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Parcourez les compétitions, puis ouvrez un championnat pour voir son détail.'**
  String get championshipsByCountrySubtitle;

  /// No description provided for @todayChip.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd’hui'**
  String get todayChip;

  /// No description provided for @tomorrowChip.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get tomorrowChip;

  /// No description provided for @weekendChip.
  ///
  /// In fr, this message translates to:
  /// **'Week-end'**
  String get weekendChip;

  /// No description provided for @allFilter.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allFilter;

  /// No description provided for @liveFilter.
  ///
  /// In fr, this message translates to:
  /// **'Live'**
  String get liveFilter;

  /// No description provided for @scheduledFilter.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get scheduledFilter;

  /// No description provided for @resultsFilter.
  ///
  /// In fr, this message translates to:
  /// **'Résultats'**
  String get resultsFilter;

  /// No description provided for @noMatchesForFiltersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rencontre'**
  String get noMatchesForFiltersTitle;

  /// No description provided for @noMatchesForFiltersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune rencontre ne correspond à ce filtre pour cette date.'**
  String get noMatchesForFiltersSubtitle;

  /// No description provided for @countryMatchSummary.
  ///
  /// In fr, this message translates to:
  /// **'{matchCount} rencontre(s) · {competitionCount} championnat(s)'**
  String countryMatchSummary(int matchCount, int competitionCount);

  /// No description provided for @competitionCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} championnat(s)'**
  String competitionCount(int count);

  /// No description provided for @calendarTab.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get calendarTab;

  /// No description provided for @matchesTab.
  ///
  /// In fr, this message translates to:
  /// **'Rencontres'**
  String get matchesTab;

  /// No description provided for @statsTab.
  ///
  /// In fr, this message translates to:
  /// **'Stats'**
  String get statsTab;

  /// No description provided for @matchCountLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} rencontre(s)'**
  String matchCountLabel(int count);

  /// No description provided for @matchesWithOddsLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} avec cotes 1N2'**
  String matchesWithOddsLabel(int count);

  /// No description provided for @competitionOddsSummary.
  ///
  /// In fr, this message translates to:
  /// **'{matchCount} rencontre(s) · {oddsCount} cotée(s)'**
  String competitionOddsSummary(int matchCount, int oddsCount);

  /// No description provided for @averageOddsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Cote moyenne'**
  String get averageOddsLabel;

  /// No description provided for @averageCompatibilityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Compatibilité moyenne'**
  String get averageCompatibilityLabel;

  /// No description provided for @oddsLabel.
  ///
  /// In fr, this message translates to:
  /// **'cote'**
  String get oddsLabel;

  /// No description provided for @homeOutcomeLabel.
  ///
  /// In fr, this message translates to:
  /// **'1'**
  String get homeOutcomeLabel;

  /// No description provided for @drawOutcomeLabel.
  ///
  /// In fr, this message translates to:
  /// **'N'**
  String get drawOutcomeLabel;

  /// No description provided for @awayOutcomeLabel.
  ///
  /// In fr, this message translates to:
  /// **'2'**
  String get awayOutcomeLabel;

  /// No description provided for @marketOddsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Cotes indisponibles'**
  String get marketOddsUnavailable;

  /// No description provided for @availableMarketsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} marché(s) MVP'**
  String availableMarketsCount(int count);

  /// No description provided for @matchDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détail rencontre'**
  String get matchDetailTitle;

  /// No description provided for @copilotReadingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lecture Lector'**
  String get copilotReadingTitle;

  /// No description provided for @notRecommendedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Non recommandé'**
  String get notRecommendedLabel;

  /// No description provided for @noCopilotSignalsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune lecture personnalisée n’est disponible pour cette rencontre.'**
  String get noCopilotSignalsMessage;

  /// No description provided for @availableMarketsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Marchés disponibles'**
  String get availableMarketsTitle;

  /// No description provided for @noAvailableMarketsMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun marché MVP n’est disponible pour cette rencontre.'**
  String get noAvailableMarketsMessage;

  /// No description provided for @analysisDataTitle.
  ///
  /// In fr, this message translates to:
  /// **'Données d’analyse'**
  String get analysisDataTitle;

  /// No description provided for @analysisUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée d’analyse exploitable n’est disponible dans le snapshot pour cette rencontre.'**
  String get analysisUnavailableMessage;

  /// No description provided for @standingsUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Aucun classement exploitable n’est disponible dans le snapshot pour cette compétition.'**
  String get standingsUnavailableMessage;

  /// No description provided for @teamAnalysisUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Données d’analyse indisponibles pour cette équipe.'**
  String get teamAnalysisUnavailableMessage;

  /// No description provided for @teamStandingUnavailableMessage.
  ///
  /// In fr, this message translates to:
  /// **'Classement indisponible pour cette équipe.'**
  String get teamStandingUnavailableMessage;

  /// No description provided for @venueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get venueLabel;

  /// No description provided for @rankShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rang'**
  String get rankShortLabel;

  /// No description provided for @pointsShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pts'**
  String get pointsShortLabel;

  /// No description provided for @playedShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'J'**
  String get playedShortLabel;

  /// No description provided for @recordShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'V-N-D'**
  String get recordShortLabel;

  /// No description provided for @goalsShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'Buts'**
  String get goalsShortLabel;

  /// No description provided for @goalsForAverageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Buts/m'**
  String get goalsForAverageLabel;

  /// No description provided for @goalsAgainstAverageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Buts enc./m'**
  String get goalsAgainstAverageLabel;

  /// No description provided for @cleanSheetsShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'CS'**
  String get cleanSheetsShortLabel;

  /// No description provided for @formShortLabel.
  ///
  /// In fr, this message translates to:
  /// **'Forme'**
  String get formShortLabel;

  /// No description provided for @showMoreMarketsButton.
  ///
  /// In fr, this message translates to:
  /// **'Voir {count} cote(s) de plus'**
  String showMoreMarketsButton(int count);

  /// No description provided for @showLessMarketsButton.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get showLessMarketsButton;

  /// No description provided for @analysisPendingLabel.
  ///
  /// In fr, this message translates to:
  /// **'À analyser'**
  String get analysisPendingLabel;

  /// No description provided for @whyButton.
  ///
  /// In fr, this message translates to:
  /// **'{count} arguments'**
  String whyButton(int count);

  /// No description provided for @addToTicket.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addToTicket;

  /// No description provided for @selectedForTicket.
  ///
  /// In fr, this message translates to:
  /// **'Retenu'**
  String get selectedForTicket;

  /// No description provided for @proofsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Preuves'**
  String get proofsLabel;

  /// No description provided for @ticketSelectionCount.
  ///
  /// In fr, this message translates to:
  /// **'Sélection en cours : {count}'**
  String ticketSelectionCount(int count);

  /// No description provided for @ticketBuilderLater.
  ///
  /// In fr, this message translates to:
  /// **'Atelier à l’étape suivante'**
  String get ticketBuilderLater;

  /// No description provided for @environmentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Environnement : {environment}'**
  String environmentLabel(String environment);

  /// No description provided for @environmentDevelopment.
  ///
  /// In fr, this message translates to:
  /// **'développement'**
  String get environmentDevelopment;

  /// No description provided for @environmentStaging.
  ///
  /// In fr, this message translates to:
  /// **'préproduction'**
  String get environmentStaging;

  /// No description provided for @environmentProduction.
  ///
  /// In fr, this message translates to:
  /// **'production'**
  String get environmentProduction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
