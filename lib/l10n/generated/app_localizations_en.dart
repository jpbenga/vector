// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lector Sport';

  @override
  String get onboardingEyebrow => 'COPILOT — SETUP';

  @override
  String get onboardingTitle => 'Let’s build your decision profile';

  @override
  String get onboardingSubtitle =>
      'Not a marketing profile. A map of how you think.';

  @override
  String onboardingQuestionProgress(int current, int total) {
    return 'QUESTION $current / $total';
  }

  @override
  String get nextButton => 'Next';

  @override
  String get backButton => 'Back';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get skipOnboardingButton => 'Skip';

  @override
  String get skipOnboardingTitle => 'Use a default configuration?';

  @override
  String get skipOnboardingMessage =>
      'Without onboarding, Copilot will apply a general configuration that is not personalized to how you make decisions.';

  @override
  String get keepOnboardingButton => 'Continue onboarding';

  @override
  String get useDefaultProfileButton => 'Use default profile';

  @override
  String get reviewProfileButton => 'Review my profile';

  @override
  String get selectedOptionsTitle => 'Prioritized selection';

  @override
  String get availableOptionsTitle => 'Available options';

  @override
  String get removeOptionTooltip => 'Remove';

  @override
  String get minOddsLabel => 'Min.';

  @override
  String get maxOddsLabel => 'Max.';

  @override
  String get noSelectedMarketsMessage => 'No favorite market selected.';

  @override
  String get noSelectionLabel => 'No selection';

  @override
  String moreValuesLabel(int count) {
    return '+ $count more';
  }

  @override
  String get profileSummaryEyebrow => 'DECISION PROFILE';

  @override
  String get profileSummaryTitle => 'Your profile';

  @override
  String get profileSummarySubtitle =>
      'Check that Copilot understood how you make decisions.';

  @override
  String get confirmProfileButton => 'Confirm and view matches';

  @override
  String get savedProfileDialogTitle => 'Saved profile';

  @override
  String get savedProfileDialogMessage =>
      'A decision profile already exists on this device. Do you want to use it for this development session?';

  @override
  String get savedProfileUseButton => 'Use this profile';

  @override
  String get savedProfileRedoButton => 'Redo onboarding';

  @override
  String get homeTitle => 'Home';

  @override
  String get editProfileTooltip => 'Edit my profile';

  @override
  String get profileSettingsButton => 'Edit my profile';

  @override
  String get forMeTab => 'For me';

  @override
  String get allMatchesTab => 'All matches';

  @override
  String forMeHeading(int count) {
    return '$count matches for your profile';
  }

  @override
  String get forMeSubtitle =>
      'These matches are shown according to your profile priorities. The engine remains separate from the interface.';

  @override
  String allMatchesHeading(int count) {
    return '$count available matches';
  }

  @override
  String get allMatchesSubtitle =>
      'No match is hidden. Copilot prioritizes, it does not remove.';

  @override
  String get championshipsByCountryTitle => 'Competitions by country';

  @override
  String get championshipsByCountrySubtitle =>
      'Browse competitions, then open one to see its details.';

  @override
  String get todayChip => 'Today';

  @override
  String get tomorrowChip => 'Tomorrow';

  @override
  String get weekendChip => 'Weekend';

  @override
  String get allFilter => 'All';

  @override
  String get liveFilter => 'Live';

  @override
  String get scheduledFilter => 'Upcoming';

  @override
  String get resultsFilter => 'Results';

  @override
  String get noMatchesForFiltersTitle => 'No matches';

  @override
  String get noMatchesForFiltersSubtitle =>
      'No matches match this filter for this date.';

  @override
  String countryMatchSummary(int matchCount, int competitionCount) {
    return '$matchCount match(es) · $competitionCount competition(s)';
  }

  @override
  String competitionCount(int count) {
    return '$count competition(s)';
  }

  @override
  String get calendarTab => 'Calendar';

  @override
  String get matchesTab => 'Matches';

  @override
  String get statsTab => 'Stats';

  @override
  String matchCountLabel(int count) {
    return '$count match(es)';
  }

  @override
  String matchesWithOddsLabel(int count) {
    return '$count with 1X2 odds';
  }

  @override
  String competitionOddsSummary(int matchCount, int oddsCount) {
    return '$matchCount match(es) · $oddsCount priced';
  }

  @override
  String get averageOddsLabel => 'Average odds';

  @override
  String get averageCompatibilityLabel => 'Average compatibility';

  @override
  String get oddsLabel => 'odds';

  @override
  String get homeOutcomeLabel => '1';

  @override
  String get drawOutcomeLabel => 'X';

  @override
  String get awayOutcomeLabel => '2';

  @override
  String get marketOddsUnavailable => 'Odds unavailable';

  @override
  String availableMarketsCount(int count) {
    return '$count MVP market(s)';
  }

  @override
  String get matchDetailTitle => 'Match detail';

  @override
  String get copilotReadingTitle => 'Copilot reading';

  @override
  String get notRecommendedLabel => 'Not recommended';

  @override
  String get noCopilotSignalsMessage =>
      'No personalized reading is available for this match.';

  @override
  String get availableMarketsTitle => 'Available markets';

  @override
  String get noAvailableMarketsMessage =>
      'No MVP market is available for this match.';

  @override
  String get analysisDataTitle => 'Analysis data';

  @override
  String get analysisUnavailableMessage =>
      'No usable analysis data is available in the snapshot for this match.';

  @override
  String get standingsUnavailableMessage =>
      'No usable standings are available in the snapshot for this competition.';

  @override
  String get teamAnalysisUnavailableMessage =>
      'Analysis data unavailable for this team.';

  @override
  String get teamStandingUnavailableMessage =>
      'Standings unavailable for this team.';

  @override
  String get venueLabel => 'Venue';

  @override
  String get rankShortLabel => 'Rank';

  @override
  String get pointsShortLabel => 'Pts';

  @override
  String get playedShortLabel => 'P';

  @override
  String get recordShortLabel => 'W-D-L';

  @override
  String get goalsShortLabel => 'Goals';

  @override
  String get goalsForAverageLabel => 'GF/m';

  @override
  String get goalsAgainstAverageLabel => 'GA/m';

  @override
  String get cleanSheetsShortLabel => 'CS';

  @override
  String get formShortLabel => 'Form';

  @override
  String showMoreMarketsButton(int count) {
    return 'Show $count more odd(s)';
  }

  @override
  String get showLessMarketsButton => 'Show less';

  @override
  String get analysisPendingLabel => 'To analyze';

  @override
  String whyButton(int count) {
    return '$count arguments';
  }

  @override
  String get addToTicket => 'Add';

  @override
  String get selectedForTicket => 'Selected';

  @override
  String get proofsLabel => 'Proofs';

  @override
  String ticketSelectionCount(int count) {
    return 'Current selection: $count';
  }

  @override
  String get ticketBuilderLater => 'Workshop in the next step';

  @override
  String environmentLabel(String environment) {
    return 'Environment: $environment';
  }

  @override
  String get environmentDevelopment => 'development';

  @override
  String get environmentStaging => 'staging';

  @override
  String get environmentProduction => 'production';
}
