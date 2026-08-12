import '../domain/decision_profile_catalogs.dart';
import '../domain/localized_label.dart';
import '../domain/onboarding_answer.dart';
import '../domain/onboarding_option.dart';
import '../domain/onboarding_question.dart';

class OnboardingQuestionnaire {
  static const version = '3.0';
  static const defaultMarketMinimumOdds = 1.30;

  static final List<OnboardingQuestion> questions = [
    OnboardingQuestion(
      id: 'competitions',
      position: 1,
      title: const LocalizedLabel(
        fr: 'Compétitions suivies',
        en: 'Followed competitions',
      ),
      subtitle: const LocalizedLabel(
        fr: 'Sélectionnez les compétitions dans lesquelles Copilot doit rechercher des opportunités.',
        en: 'Select the competitions where Copilot should search for opportunities.',
      ),
      type: OnboardingQuestionType.multiSelect,
      options: [
        for (final competition in CompetitionCatalog.values)
          OnboardingOption(
            id: competition.id,
            label: LocalizedLabel(fr: competition.name, en: competition.name),
          ),
      ],
    ),
    const OnboardingQuestion(
      id: 'markets',
      position: 2,
      title: LocalizedLabel(fr: 'Marchés joués', en: 'Played markets'),
      subtitle: LocalizedLabel(
        fr: 'Les marchés ne sélectionnent pas les matchs : ils traduisent une opportunité en pick possible.',
        en: 'Markets do not select matches: they translate an opportunity into a possible pick.',
      ),
      type: OnboardingQuestionType.multiSelect,
      options: [
        OnboardingOption(
          id: 'match_result',
          label: LocalizedLabel(fr: '1 N 2', en: '1 X 2'),
        ),
        OnboardingOption(
          id: 'both_teams_score',
          label: LocalizedLabel(
            fr: 'But pour les 2 équipes',
            en: 'Both teams to score',
          ),
        ),
        OnboardingOption(
          id: 'team_scores',
          label: LocalizedLabel(
            fr: 'But équipe domicile / extérieur',
            en: 'Home / away team goals',
          ),
        ),
        OnboardingOption(
          id: 'goals_over_under',
          label: LocalizedLabel(
            fr: 'Over / Under buts',
            en: 'Goals over / under',
          ),
        ),
        OnboardingOption(
          id: 'corners',
          label: LocalizedLabel(fr: 'Corners', en: 'Corners'),
        ),
        OnboardingOption(
          id: 'cards',
          label: LocalizedLabel(fr: 'Cartons', en: 'Cards'),
        ),
        OnboardingOption(
          id: 'double_chance',
          label: LocalizedLabel(fr: 'Double chance', en: 'Double chance'),
        ),
        OnboardingOption(
          id: 'player_scorer',
          label: LocalizedLabel(fr: 'Buteur', en: 'Player scorer'),
        ),
      ],
    ),
    const OnboardingQuestion(
      id: 'opportunity_profiles',
      position: 3,
      title: LocalizedLabel(
        fr: 'Profils d’opportunités recherchés',
        en: 'Searched opportunity profiles',
      ),
      subtitle: LocalizedLabel(
        fr: 'Une opportunité apparaît dans Pour moi lorsqu’elle correspond à au moins un profil activé.',
        en: 'An opportunity appears in For me when it matches at least one enabled profile.',
      ),
      type: OnboardingQuestionType.multiSelect,
      options: [
        OnboardingOption(
          id: 'solid_favorite',
          label: LocalizedLabel(fr: 'Favoris solides', en: 'Solid favorites'),
        ),
        OnboardingOption(
          id: 'struggling_team',
          label: LocalizedLabel(
            fr: 'Équipes en difficulté · à venir',
            en: 'Struggling teams · soon',
          ),
          isEnabled: false,
        ),
        OnboardingOption(
          id: 'offensive_match',
          label: LocalizedLabel(fr: 'Matchs ouverts', en: 'Open matches'),
        ),
        OnboardingOption(
          id: 'defensive_match',
          label: LocalizedLabel(fr: 'Matchs fermés', en: 'Closed matches'),
        ),
        OnboardingOption(
          id: 'ranking_gap',
          label: LocalizedLabel(fr: 'Écarts de niveau', en: 'Level gaps'),
        ),
        OnboardingOption(
          id: 'credible_outsider',
          label: LocalizedLabel(
            fr: 'Outsiders crédibles',
            en: 'Credible outsiders',
          ),
        ),
        OnboardingOption(
          id: 'fragile_defense',
          label: LocalizedLabel(
            fr: 'Défenses fragiles · à venir',
            en: 'Fragile defenses · soon',
          ),
          isEnabled: false,
        ),
        OnboardingOption(
          id: 'prolific_attack',
          label: LocalizedLabel(
            fr: 'Attaques prolifiques · à venir',
            en: 'Prolific attacks · soon',
          ),
          isEnabled: false,
        ),
        OnboardingOption(
          id: 'positive_series',
          label: LocalizedLabel(
            fr: 'Séries positives · à venir',
            en: 'Positive streaks · soon',
          ),
          isEnabled: false,
        ),
        OnboardingOption(
          id: 'negative_series',
          label: LocalizedLabel(
            fr: 'Séries négatives · à venir',
            en: 'Negative streaks · soon',
          ),
          isEnabled: false,
        ),
      ],
    ),
    const OnboardingQuestion(
      id: 'ticket_strategies',
      position: 4,
      title: LocalizedLabel(
        fr: 'Stratégies de tickets',
        en: 'Ticket strategies',
      ),
      subtitle: LocalizedLabel(
        fr: 'Créez une ou plusieurs stratégies. C’est recommandé, mais pas obligatoire.',
        en: 'Create one or more strategies. Recommended, but optional.',
      ),
      type: OnboardingQuestionType.ticketStrategies,
      options: [],
    ),
  ];

  static OnboardingQuestion questionById(String questionId) {
    return questions.firstWhere((question) => question.id == questionId);
  }

  static OnboardingAnswer defaultAnswerFor(OnboardingQuestion question) {
    return switch (question.type) {
      OnboardingQuestionType.multiSelect => OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: const [],
      ),
      OnboardingQuestionType.singleChoice => OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: const [],
      ),
      OnboardingQuestionType.ticketStrategies => OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: const [],
      ),
      OnboardingQuestionType.multiSelectRanking => OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: const [],
      ),
      OnboardingQuestionType.editableOddsRanges => OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: const [],
      ),
      OnboardingQuestionType.marketMinimumOdds => OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: const [],
      ),
      OnboardingQuestionType.scale => OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: const [],
        scaleValue: null,
      ),
    };
  }

  const OnboardingQuestionnaire._();
}
