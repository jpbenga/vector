// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Lector Sport';

  @override
  String get onboardingEyebrow => 'COPILOT — MISE EN ROUTE';

  @override
  String get onboardingTitle => 'Construisons votre profil de décision';

  @override
  String get onboardingSubtitle =>
      'Pas un profil marketing. Une carte de votre façon de réfléchir.';

  @override
  String onboardingQuestionProgress(int current, int total) {
    return 'QUESTION $current / $total';
  }

  @override
  String get nextButton => 'Suivant';

  @override
  String get backButton => 'Retour';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get skipOnboardingButton => 'Passer';

  @override
  String get skipOnboardingTitle => 'Utiliser une configuration par défaut ?';

  @override
  String get skipOnboardingMessage =>
      'Sans onboarding, Copilot appliquera une configuration générale qui ne sera pas personnalisée à votre manière de décider.';

  @override
  String get keepOnboardingButton => 'Continuer l’onboarding';

  @override
  String get useDefaultProfileButton => 'Utiliser le profil par défaut';

  @override
  String get reviewProfileButton => 'Voir mon profil';

  @override
  String get selectedOptionsTitle => 'Sélection priorisée';

  @override
  String get availableOptionsTitle => 'Options disponibles';

  @override
  String get removeOptionTooltip => 'Retirer';

  @override
  String get minOddsLabel => 'Min.';

  @override
  String get maxOddsLabel => 'Max.';

  @override
  String get noSelectedMarketsMessage => 'Aucun marché favori sélectionné.';

  @override
  String get noSelectionLabel => 'Aucune sélection';

  @override
  String moreValuesLabel(int count) {
    return '+ $count autres';
  }

  @override
  String get profileSummaryEyebrow => 'PROFIL DE DÉCISION';

  @override
  String get profileSummaryTitle => 'Votre profil';

  @override
  String get profileSummarySubtitle =>
      'Vérifiez que Copilot a correctement compris votre manière de décider.';

  @override
  String get confirmProfileButton => 'Valider et voir les matchs';

  @override
  String get savedProfileDialogTitle => 'Profil sauvegardé';

  @override
  String get savedProfileDialogMessage =>
      'Un profil de décision existe déjà sur cet appareil. Voulez-vous l’utiliser pour cette session de développement ?';

  @override
  String get savedProfileUseButton => 'Utiliser ce profil';

  @override
  String get savedProfileRedoButton => 'Refaire l’onboarding';

  @override
  String get homeTitle => 'Accueil';

  @override
  String get editProfileTooltip => 'Modifier mon profil';

  @override
  String get profileSettingsButton => 'Modifier mon profil';

  @override
  String get forMeTab => 'Pour moi';

  @override
  String get allMatchesTab => 'Toutes les rencontres';

  @override
  String forMeHeading(int count) {
    return '$count rencontres pour votre profil';
  }

  @override
  String get forMeSubtitle =>
      'Ces rencontres sont affichées selon les priorités de votre profil. Le moteur reste séparé de l’interface.';

  @override
  String allMatchesHeading(int count) {
    return '$count rencontres disponibles';
  }

  @override
  String get allMatchesSubtitle =>
      'Aucune rencontre n’est masquée. Copilot priorise, il ne supprime pas.';

  @override
  String get championshipsByCountryTitle => 'Championnats par pays';

  @override
  String get championshipsByCountrySubtitle =>
      'Parcourez les compétitions, puis ouvrez un championnat pour voir son détail.';

  @override
  String get todayChip => 'Aujourd’hui';

  @override
  String get tomorrowChip => 'Demain';

  @override
  String get weekendChip => 'Week-end';

  @override
  String get allFilter => 'Tous';

  @override
  String get liveFilter => 'Live';

  @override
  String get scheduledFilter => 'À venir';

  @override
  String get resultsFilter => 'Résultats';

  @override
  String get noMatchesForFiltersTitle => 'Aucune rencontre';

  @override
  String get noMatchesForFiltersSubtitle =>
      'Aucune rencontre ne correspond à ce filtre pour cette date.';

  @override
  String countryMatchSummary(int matchCount, int competitionCount) {
    return '$matchCount rencontre(s) · $competitionCount championnat(s)';
  }

  @override
  String competitionCount(int count) {
    return '$count championnat(s)';
  }

  @override
  String get calendarTab => 'Calendrier';

  @override
  String get matchesTab => 'Rencontres';

  @override
  String get statsTab => 'Stats';

  @override
  String matchCountLabel(int count) {
    return '$count rencontre(s)';
  }

  @override
  String matchesWithOddsLabel(int count) {
    return '$count avec cotes 1N2';
  }

  @override
  String competitionOddsSummary(int matchCount, int oddsCount) {
    return '$matchCount rencontre(s) · $oddsCount cotée(s)';
  }

  @override
  String get averageOddsLabel => 'Cote moyenne';

  @override
  String get averageCompatibilityLabel => 'Compatibilité moyenne';

  @override
  String get oddsLabel => 'cote';

  @override
  String get homeOutcomeLabel => '1';

  @override
  String get drawOutcomeLabel => 'N';

  @override
  String get awayOutcomeLabel => '2';

  @override
  String get marketOddsUnavailable => 'Cotes indisponibles';

  @override
  String availableMarketsCount(int count) {
    return '$count marché(s) MVP';
  }

  @override
  String get matchDetailTitle => 'Détail rencontre';

  @override
  String get copilotReadingTitle => 'Lecture Copilot';

  @override
  String get notRecommendedLabel => 'Non recommandé';

  @override
  String get noCopilotSignalsMessage =>
      'Aucune lecture personnalisée n’est disponible pour cette rencontre.';

  @override
  String get availableMarketsTitle => 'Marchés disponibles';

  @override
  String get noAvailableMarketsMessage =>
      'Aucun marché MVP n’est disponible pour cette rencontre.';

  @override
  String get analysisDataTitle => 'Données d’analyse';

  @override
  String get analysisUnavailableMessage =>
      'Aucune donnée d’analyse exploitable n’est disponible dans le snapshot pour cette rencontre.';

  @override
  String get standingsUnavailableMessage =>
      'Aucun classement exploitable n’est disponible dans le snapshot pour cette compétition.';

  @override
  String get teamAnalysisUnavailableMessage =>
      'Données d’analyse indisponibles pour cette équipe.';

  @override
  String get teamStandingUnavailableMessage =>
      'Classement indisponible pour cette équipe.';

  @override
  String get venueLabel => 'Lieu';

  @override
  String get rankShortLabel => 'Rang';

  @override
  String get pointsShortLabel => 'Pts';

  @override
  String get playedShortLabel => 'J';

  @override
  String get recordShortLabel => 'V-N-D';

  @override
  String get goalsShortLabel => 'Buts';

  @override
  String get goalsForAverageLabel => 'Buts/m';

  @override
  String get goalsAgainstAverageLabel => 'Buts enc./m';

  @override
  String get cleanSheetsShortLabel => 'CS';

  @override
  String get formShortLabel => 'Forme';

  @override
  String showMoreMarketsButton(int count) {
    return 'Voir $count cote(s) de plus';
  }

  @override
  String get showLessMarketsButton => 'Réduire';

  @override
  String get analysisPendingLabel => 'À analyser';

  @override
  String whyButton(int count) {
    return '$count arguments';
  }

  @override
  String get addToTicket => 'Ajouter';

  @override
  String get selectedForTicket => 'Retenu';

  @override
  String get proofsLabel => 'Preuves';

  @override
  String ticketSelectionCount(int count) {
    return 'Sélection en cours : $count';
  }

  @override
  String get ticketBuilderLater => 'Atelier à l’étape suivante';

  @override
  String environmentLabel(String environment) {
    return 'Environnement : $environment';
  }

  @override
  String get environmentDevelopment => 'développement';

  @override
  String get environmentStaging => 'préproduction';

  @override
  String get environmentProduction => 'production';
}
