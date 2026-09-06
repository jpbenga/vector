import 'package:flutter/material.dart';

import '../../../app/auth/auth_menu_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../tickets/domain/ticket_strategy.dart';
import '../../matches/presentation/widgets/sports_asset_badge.dart';
import '../data/onboarding_questionnaire.dart';
import '../domain/decision_profile.dart';
import '../domain/decision_profile_catalogs.dart';
import '../domain/onboarding_answer.dart';
import '../domain/onboarding_completion.dart';
import '../domain/onboarding_option.dart';
import '../domain/onboarding_question.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.onCompleted,
    this.initialProfile,
    this.initialTicketStrategies = const [],
    this.onCancel,
    super.key,
  });

  final ValueChanged<OnboardingCompletion> onCompleted;
  final DecisionProfile? initialProfile;
  final List<TicketStrategy> initialTicketStrategies;
  final VoidCallback? onCancel;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _localUserId = 'local-user';

  late final Map<String, OnboardingAnswer> _answers;
  late List<TicketStrategy> _ticketStrategies;

  int _questionIndex = 0;
  bool _showsSummary = false;
  bool _showsCompleted = false;

  @override
  void initState() {
    super.initState();
    _answers = {
      for (final question in OnboardingQuestionnaire.questions)
        question.id:
            _initialAnswerFor(question) ??
            OnboardingQuestionnaire.defaultAnswerFor(question),
    };
    _ticketStrategies = [...widget.initialTicketStrategies];
  }

  @override
  Widget build(BuildContext context) {
    final questions = OnboardingQuestionnaire.questions;
    final profile = _buildProfile();

    if (_showsCompleted) {
      return _OnboardingCompletedScreen(
        onExplore: () {
          widget.onCompleted(
            OnboardingCompletion(
              profile: profile,
              ticketStrategies: List.unmodifiable(_ticketStrategies),
            ),
          );
        },
        onEditProfile: () {
          setState(() {
            _showsCompleted = false;
            _showsSummary = false;
            _questionIndex = 0;
          });
        },
      );
    }

    if (_showsSummary) {
      return _OnboardingSummaryScreen(
        profile: profile,
        questions: questions,
        strategies: _ticketStrategies,
        onEditQuestion: (index) {
          setState(() {
            _showsSummary = false;
            _questionIndex = index;
          });
        },
        onBack: () {
          setState(() {
            _showsSummary = false;
            _questionIndex = questions.length - 1;
          });
        },
        onCancel: widget.onCancel,
        onConfirm: () {
          setState(() {
            _showsCompleted = true;
          });
        },
      );
    }

    final question = questions[_questionIndex];
    final locale = Localizations.localeOf(context);
    final canContinue = _canContinue(question);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                children: [
                  _OnboardingTopBar(
                    canGoBack: _questionIndex > 0,
                    onBack: _questionIndex > 0
                        ? () {
                            setState(() {
                              _questionIndex -= 1;
                            });
                          }
                        : null,
                    onCancel: widget.onCancel,
                  ),
                  const SizedBox(height: 18),
                  _StepIndicator(
                    currentIndex: _questionIndex,
                    totalCount: questions.length,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                children: [
                  Text(
                    question.title.resolve(locale),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.subtitle.resolve(locale),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _QuestionBody(
                    question: question,
                    answer: _answers[question.id]!,
                    strategies: _ticketStrategies,
                    strategyDraft: _newStrategyDraft(),
                    onAnswerChanged: (answer) {
                      setState(() {
                        _answers[question.id] = answer;
                      });
                    },
                    onStrategiesChanged: (strategies) {
                      setState(() {
                        _ticketStrategies = strategies;
                      });
                    },
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!canContinue) ...[
                      _ValidationNotice(message: _validationMessage(question)),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: canContinue
                            ? () {
                                setState(() {
                                  if (_questionIndex == questions.length - 1) {
                                    _showsSummary = true;
                                  } else {
                                    _questionIndex += 1;
                                  }
                                });
                              }
                            : null,
                        child: Text(
                          _questionIndex == questions.length - 1
                              ? 'Voir mon profil'
                              : 'Continuer',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  OnboardingAnswer? _initialAnswerFor(OnboardingQuestion question) {
    final profile = widget.initialProfile;
    if (profile == null) {
      return null;
    }

    try {
      return _normalizeInitialAnswer(question, profile.answerFor(question.id));
    } on StateError {
      if (question.id == 'opportunity_profiles') {
        try {
          return _normalizeInitialAnswer(
            question,
            profile
                .answerFor('match_types')
                .copyWith(
                  orderedOptionIds: profile
                      .answerFor('match_types')
                      .orderedOptionIds,
                ),
          );
        } on StateError {
          return null;
        }
      }
      return null;
    }
  }

  OnboardingAnswer _normalizeInitialAnswer(
    OnboardingQuestion question,
    OnboardingAnswer answer,
  ) {
    if (question.id == 'competitions') {
      return answer.copyWith(
        orderedOptionIds: [
          for (final optionId in answer.orderedOptionIds)
            if (CompetitionCatalog.resolveId(optionId) != null)
              CompetitionCatalog.resolveId(optionId)!,
        ],
      );
    }

    if (question.id == 'opportunity_profiles') {
      return OnboardingAnswer(
        questionId: question.id,
        orderedOptionIds: [
          for (final optionId in answer.orderedOptionIds)
            if (OpportunityProfileCatalog.byId(optionId)?.isSupported == true)
              optionId,
        ],
      );
    }

    return answer;
  }

  bool _canContinue(OnboardingQuestion question) {
    final answer = _answers[question.id]!;

    return switch (question.id) {
      'competitions' => answer.orderedOptionIds.isNotEmpty,
      'markets' => answer.orderedOptionIds.isNotEmpty,
      'opportunity_profiles' => answer.orderedOptionIds.isNotEmpty,
      _ => true,
    };
  }

  String _validationMessage(OnboardingQuestion question) {
    return switch (question.id) {
      'competitions' => 'Sélectionnez au moins une compétition.',
      'markets' => 'Sélectionnez au moins un marché.',
      'opportunity_profiles' =>
        'Sélectionnez au moins un profil d’opportunité disponible.',
      _ => '',
    };
  }

  DecisionProfile _buildProfile() {
    return DecisionProfile(
      onboardingVersion: OnboardingQuestionnaire.version,
      answers: [
        for (final question in OnboardingQuestionnaire.questions)
          if (question.id != 'ticket_strategies') _answers[question.id]!,
      ],
    );
  }

  String _nextStrategyId() {
    return 'strategy-${DateTime.now().microsecondsSinceEpoch}';
  }

  TicketStrategy _newStrategyDraft() {
    final now = DateTime.now().toUtc();
    return TicketStrategy(
      schemaVersion: TicketStrategy.currentSchemaVersion,
      id: _nextStrategyId(),
      userId: _localUserId,
      name: 'Nouvelle stratégie',
      isActive: true,
      pickTypes: const [PickType.prudent, PickType.normal],
      minimumIndividualOdds: 0,
      maximumIndividualOdds: 2.19,
      minimumSelections: 2,
      maximumSelections: 3,
      minimumTotalOdds: 2.00,
      maximumTotalOdds: 3.00,
      priority: _ticketStrategies.length + 1,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    required this.question,
    required this.answer,
    required this.strategies,
    required this.strategyDraft,
    required this.onAnswerChanged,
    required this.onStrategiesChanged,
  });

  final OnboardingQuestion question;
  final OnboardingAnswer answer;
  final List<TicketStrategy> strategies;
  final TicketStrategy strategyDraft;
  final ValueChanged<OnboardingAnswer> onAnswerChanged;
  final ValueChanged<List<TicketStrategy>> onStrategiesChanged;

  @override
  Widget build(BuildContext context) {
    if (question.id == 'competitions') {
      return _CompetitionGroupedSelectView(
        selectedOptionIds: answer.orderedOptionIds,
        onChanged: (ids) {
          onAnswerChanged(answer.copyWith(orderedOptionIds: ids));
        },
      );
    }

    if (question.id == 'markets') {
      return _MarketCardsSelectView(
        selectedOptionIds: answer.orderedOptionIds,
        onChanged: (ids) {
          onAnswerChanged(answer.copyWith(orderedOptionIds: ids));
        },
      );
    }

    if (question.id == 'opportunity_profiles') {
      return _OpportunityProfileCardsView(
        selectedOptionIds: answer.orderedOptionIds,
        onChanged: (ids) {
          onAnswerChanged(answer.copyWith(orderedOptionIds: ids));
        },
      );
    }

    return switch (question.type) {
      OnboardingQuestionType.multiSelect => _MultiSelectQuestionView(
        options: question.options,
        selectedOptionIds: answer.orderedOptionIds,
        onChanged: (ids) {
          onAnswerChanged(answer.copyWith(orderedOptionIds: ids));
        },
      ),
      OnboardingQuestionType.singleChoice => _SingleChoiceQuestionView(
        options: question.options,
        selectedOptionId: answer.orderedOptionIds.firstOrNull,
        onChanged: (option) {
          onAnswerChanged(answer.copyWith(orderedOptionIds: [option.id]));
        },
      ),
      OnboardingQuestionType.ticketStrategies => _TicketStrategiesQuestionView(
        strategies: strategies,
        strategyDraft: strategyDraft,
        onChanged: onStrategiesChanged,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.canGoBack,
    required this.onBack,
    required this.onCancel,
  });

  final bool canGoBack;
  final VoidCallback? onBack;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        IconButton(
          onPressed: canGoBack ? onBack : onCancel,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: canGoBack ? 'Retour' : 'Annuler',
        ),
        Expanded(
          child: Text(
            'Onboarding',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const AuthMenuButton(),
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Annuler',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentIndex, required this.totalCount});

  final int currentIndex;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var index = 0; index < totalCount; index++) ...[
          _StepDot(index: index, isActive: index <= currentIndex),
          if (index < totalCount - 1)
            Expanded(
              child: Container(
                height: 1,
                color: index < currentIndex
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.isActive});

  final int index;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: SizedBox.square(
        dimension: 28,
        child: Center(
          child: Text(
            '${index + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isActive
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ValidationNotice extends StatelessWidget {
  const _ValidationNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectQuestionView extends StatelessWidget {
  const _MultiSelectQuestionView({
    required this.options,
    required this.selectedOptionIds,
    required this.onChanged,
  });

  final List<OnboardingOption> options;
  final List<String> selectedOptionIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option.label.resolve(locale)),
            selected: selectedOptionIds.contains(option.id),
            onSelected: option.isEnabled
                ? (selected) {
                    if (selected) {
                      onChanged([...selectedOptionIds, option.id]);
                    } else {
                      onChanged([
                        for (final id in selectedOptionIds)
                          if (id != option.id) id,
                      ]);
                    }
                  }
                : null,
          ),
      ],
    );
  }
}

class _CompetitionGroupedSelectView extends StatefulWidget {
  const _CompetitionGroupedSelectView({
    required this.selectedOptionIds,
    required this.onChanged,
  });

  final List<String> selectedOptionIds;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_CompetitionGroupedSelectView> createState() =>
      _CompetitionGroupedSelectViewState();
}

class _CompetitionGroupedSelectViewState
    extends State<_CompetitionGroupedSelectView> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCountryCodes = {};

  @override
  void initState() {
    super.initState();
    final firstCountry =
        RuntimeCompetitionCatalog.values.firstOrNull?.countryCode;
    if (firstCountry != null) {
      _expandedCountryCodes.add(firstCountry);
    }
    for (final competition in RuntimeCompetitionCatalog.values) {
      if (widget.selectedOptionIds.contains(competition.id)) {
        _expandedCountryCodes.add(competition.countryCode);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final search = _searchController.text.trim().toLowerCase();
    final groups = <String, List<DecisionCompetitionDefinition>>{};
    for (final competition in RuntimeCompetitionCatalog.values) {
      if (search.isNotEmpty &&
          !competition.name.toLowerCase().contains(search) &&
          !competition.countryName.toLowerCase().contains(search)) {
        continue;
      }
      groups.putIfAbsent(competition.countryCode, () => []).add(competition);
    }

    final orderedGroups = groups.entries.toList()
      ..sort(
        (a, b) =>
            a.value.first.countryName.compareTo(b.value.first.countryName),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Rechercher une compétition',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.selectedOptionIds.length} compétition(s) sélectionnée(s)',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        for (final group in orderedGroups)
          _CompetitionCountryCard(
            country: group.value.first.country,
            competitions: group.value,
            selectedOptionIds: widget.selectedOptionIds,
            isExpanded:
                search.isNotEmpty ||
                _expandedCountryCodes.contains(group.value.first.countryCode),
            onToggleExpanded: () {
              final countryCode = group.value.first.countryCode;
              setState(() {
                if (_expandedCountryCodes.contains(countryCode)) {
                  _expandedCountryCodes.remove(countryCode);
                } else {
                  _expandedCountryCodes.add(countryCode);
                }
              });
            },
            onToggleCompetition: _toggleCompetition,
          ),
      ],
    );
  }

  void _toggleCompetition(String competitionId, bool selected) {
    if (selected) {
      widget.onChanged([...widget.selectedOptionIds, competitionId]);
    } else {
      widget.onChanged([
        for (final id in widget.selectedOptionIds)
          if (id != competitionId) id,
      ]);
    }
  }
}

class _CompetitionCountryCard extends StatelessWidget {
  const _CompetitionCountryCard({
    required this.country,
    required this.competitions,
    required this.selectedOptionIds,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onToggleCompetition,
  });

  final CompetitionCountryDefinition country;
  final List<DecisionCompetitionDefinition> competitions;
  final List<String> selectedOptionIds;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final void Function(String competitionId, bool selected) onToggleCompetition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedCount = competitions
        .where((competition) => selectedOptionIds.contains(competition.id))
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    _CountryFlag(country: country),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        country.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$selectedCount/${competitions.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    for (final competition in competitions)
                      CheckboxListTile(
                        key: ValueKey('competition-${competition.id}'),
                        value: selectedOptionIds.contains(competition.id),
                        onChanged: (selected) => onToggleCompetition(
                          competition.id,
                          selected ?? false,
                        ),
                        title: Row(
                          children: [
                            SportsAssetBadge(
                              size: 24,
                              imageUrl: competition.logoUrl,
                              fallbackLabel: competition.name,
                              borderRadius: 6,
                              padding: 2,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(competition.name)),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountryFlag extends StatelessWidget {
  const _CountryFlag({required this.country});

  final CompetitionCountryDefinition country;

  @override
  Widget build(BuildContext context) {
    return SportsAssetBadge(
      size: 24,
      imageUrl: country.flagUrl,
      fallbackLabel: country.code,
      borderRadius: 3,
      padding: 0,
    );
  }
}

class _SingleChoiceQuestionView extends StatelessWidget {
  const _SingleChoiceQuestionView({
    required this.options,
    required this.selectedOptionId,
    required this.onChanged,
  });

  final List<OnboardingOption> options;
  final String? selectedOptionId;
  final ValueChanged<OnboardingOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                side: BorderSide(
                  color: selectedOptionId == option.id
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: () => onChanged(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedOptionId == option.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selectedOptionId == option.id
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(option.label.resolve(locale))),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MarketCardsSelectView extends StatelessWidget {
  const _MarketCardsSelectView({
    required this.selectedOptionIds,
    required this.onChanged,
  });

  final List<String> selectedOptionIds;
  final ValueChanged<List<String>> onChanged;

  static const _markets = [
    _MarketCardData(
      id: 'match_result',
      title: 'Résultat du match',
      subtitle: '1N2',
      icon: Icons.shield_outlined,
    ),
    _MarketCardData(
      id: 'double_chance',
      title: 'Double chance',
      subtitle: '1X, X2, 12',
      icon: Icons.looks_two_outlined,
    ),
    _MarketCardData(
      id: 'goals_over_under',
      title: 'Plus / Moins (buts)',
      subtitle: '0.5, 1.5, 2.5, 3.5',
      icon: Icons.track_changes_rounded,
    ),
    _MarketCardData(
      id: 'both_teams_score',
      title: 'Les deux équipes marquent',
      subtitle: 'Oui / Non',
      icon: Icons.sync_alt_rounded,
    ),
    _MarketCardData(
      id: 'team_scores',
      title: 'But équipe',
      subtitle: 'Domicile / extérieur',
      icon: Icons.sports_soccer_rounded,
    ),
    _MarketCardData(
      id: 'player_scorer',
      title: 'Buteur',
      subtitle: 'Buteur à tout moment',
      icon: Icons.person_pin_circle_outlined,
      badge: 'Nouveau',
      notice:
          'Le marché Buteur est disponible dans le produit, mais pas encore pris en charge par toutes nos analyses.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final market in _markets)
          _SelectableSetupCard(
            title: market.title,
            subtitle: market.subtitle,
            icon: market.icon,
            badge: market.badge,
            isSelected: selectedOptionIds.contains(market.id),
            isEnabled: true,
            onTap: () => _toggle(market.id),
          ),
        const _SetupNotice(
          icon: Icons.info_outline_rounded,
          text:
              'Le marché Buteur est disponible mais ne sera pas encore proposé par toutes nos analyses.',
        ),
      ],
    );
  }

  void _toggle(String optionId) {
    if (selectedOptionIds.contains(optionId)) {
      onChanged([
        for (final id in selectedOptionIds)
          if (id != optionId) id,
      ]);
    } else {
      onChanged([...selectedOptionIds, optionId]);
    }
  }
}

class _OpportunityProfileCardsView extends StatelessWidget {
  const _OpportunityProfileCardsView({
    required this.selectedOptionIds,
    required this.onChanged,
  });

  final List<String> selectedOptionIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final profile in OpportunityProfileCatalog.values)
          _SelectableSetupCard(
            title: profile.displayLabel,
            subtitle: profile.description,
            icon: context.opportunities.iconForProfileId(profile.id),
            badge: profile.isSupported ? null : 'À venir',
            isSelected: selectedOptionIds.contains(profile.id),
            isEnabled: profile.isSupported,
            onTap: profile.isSupported ? () => _toggle(profile.id) : null,
          ),
        const _SetupNotice(
          icon: Icons.info_outline_rounded,
          text:
              'Les profils marqués “À venir” seront disponibles prochainement.',
        ),
      ],
    );
  }

  void _toggle(String optionId) {
    if (selectedOptionIds.contains(optionId)) {
      onChanged([
        for (final id in selectedOptionIds)
          if (id != optionId) id,
      ]);
    } else {
      onChanged([...selectedOptionIds, optionId]);
    }
  }
}

class _SelectableSetupCard extends StatelessWidget {
  const _SelectableSetupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = isEnabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.76),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isEnabled
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (badge != null) _SmallBadge(label: badge!),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isSelected
                      ? Icons.check_box_rounded
                      : isEnabled
                      ? Icons.check_box_outline_blank_rounded
                      : Icons.lock_outline_rounded,
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketCardData {
  const _MarketCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.notice,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final String? notice;
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketStrategiesQuestionView extends StatelessWidget {
  const _TicketStrategiesQuestionView({
    required this.strategies,
    required this.strategyDraft,
    required this.onChanged,
  });

  final List<TicketStrategy> strategies;
  final TicketStrategy strategyDraft;
  final ValueChanged<List<TicketStrategy>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StrategyHint(hasStrategies: strategies.isNotEmpty),
        const SizedBox(height: 14),
        _NewStrategyCard(
          key: const ValueKey('create-strategy-button'),
          onTap: () async {
            final result = await _showStrategyEditor(
              context,
              initialStrategy: strategyDraft,
              canDelete: false,
            );
            final created = result?.strategy;
            if (created != null) {
              onChanged([...strategies, created]);
            }
          },
        ),
        const SizedBox(height: 16),
        for (final strategy in strategies)
          _StrategyCard(
            strategy: strategy,
            onToggleActive: (isActive) {
              onChanged([
                for (final item in strategies)
                  if (item.id == strategy.id)
                    item.copyWith(
                      isActive: isActive,
                      updatedAt: DateTime.now().toUtc(),
                    )
                  else
                    item,
              ]);
            },
            onEdit: () async {
              final result = await _showStrategyEditor(
                context,
                initialStrategy: strategy,
                canDelete: true,
              );
              if (result?.isDeleted == true) {
                onChanged([
                  for (final item in strategies)
                    if (item.id != strategy.id) item,
                ]);
                return;
              }
              final updated = result?.strategy;
              if (updated != null) {
                onChanged([
                  for (final item in strategies)
                    if (item.id == strategy.id) updated else item,
                ]);
              }
            },
            onDelete: () {
              onChanged([
                for (final item in strategies)
                  if (item.id != strategy.id) item,
              ]);
            },
          ),
      ],
    );
  }

  Future<_StrategyEditorResult?> _showStrategyEditor(
    BuildContext context, {
    TicketStrategy? initialStrategy,
    required bool canDelete,
  }) {
    return Navigator.of(context).push<_StrategyEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _TicketStrategyEditorPage(
          strategy: initialStrategy!,
          canDelete: canDelete,
        ),
      ),
    );
  }
}

class _StrategyEditorResult {
  const _StrategyEditorResult.saved(this.strategy) : isDeleted = false;

  const _StrategyEditorResult.deleted() : strategy = null, isDeleted = true;

  final TicketStrategy? strategy;
  final bool isDeleted;
}

class _NewStrategyCard extends StatelessWidget {
  const _NewStrategyCard({required super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                'Nouvelle stratégie',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketStrategyEditorPage extends StatelessWidget {
  const _TicketStrategyEditorPage({
    required this.strategy,
    required this.canDelete,
  });

  final TicketStrategy strategy;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _TicketStrategyDialog(strategy: strategy, canDelete: canDelete),
      ),
    );
  }
}

class _StrategyHint extends StatelessWidget {
  const _StrategyHint({required this.hasStrategies});

  final bool hasStrategies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              hasStrategies
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasStrategies
                    ? 'Vos stratégies seront sauvegardées à la validation finale.'
                    : 'Aucune stratégie créée : le profil pourra être complet, mais les tickets automatiques resteront indisponibles.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({
    required this.strategy,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final TicketStrategy strategy;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxOdds = strategy.maximumTotalOdds;
    final maxIndividualOdds = strategy.maximumIndividualOdds;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_strategyIcon(strategy), color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strategy.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick ${strategy.minimumIndividualOdds.toStringAsFixed(2)} - ${maxIndividualOdds?.toStringAsFixed(2) ?? 'ouverte'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: strategy.isActive, onChanged: onToggleActive),
                  IconButton(
                    tooltip: 'Modifier',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${strategy.minimumSelections}-${strategy.maximumSelections} sélections',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cotes individuelles : ${strategy.minimumIndividualOdds.toStringAsFixed(2)} - ${maxIndividualOdds?.toStringAsFixed(2) ?? 'ouverte'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cote totale : ${strategy.minimumTotalOdds.toStringAsFixed(2)} - ${maxOdds?.toStringAsFixed(2) ?? 'ouverte'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(label: strategy.isActive ? 'Active' : 'Inactive'),
                  _InfoChip(
                    label:
                        'Pick ${strategy.minimumIndividualOdds.toStringAsFixed(2)}-${maxIndividualOdds?.toStringAsFixed(2) ?? 'ouverte'}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _strategyIcon(TicketStrategy strategy) {
    if (strategy.maximumIndividualOdds == null ||
        strategy.maximumIndividualOdds! >= 2.20) {
      return Icons.rocket_launch_outlined;
    }
    if (strategy.maximumIndividualOdds! <= 1.49) {
      return Icons.shield_outlined;
    }
    return Icons.balance_rounded;
  }
}

class _TicketStrategyDialog extends StatefulWidget {
  const _TicketStrategyDialog({
    required this.strategy,
    required this.canDelete,
  });

  final TicketStrategy strategy;
  final bool canDelete;

  @override
  State<_TicketStrategyDialog> createState() => _TicketStrategyDialogState();
}

class _TicketStrategyDialogState extends State<_TicketStrategyDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _minimumIndividualOddsController;
  late final TextEditingController _maximumIndividualOddsController;
  late final TextEditingController _minimumSelectionsController;
  late final TextEditingController _maximumSelectionsController;
  late final TextEditingController _minimumTotalOddsController;
  late final TextEditingController _maximumTotalOddsController;
  late bool _isActive;
  bool _maximumIndividualOddsTouched = false;
  bool _maximumTotalOddsTouched = false;

  @override
  void initState() {
    super.initState();
    final strategy = widget.strategy;
    _nameController = TextEditingController(text: strategy.name);
    final fillsExistingValues = widget.canDelete;
    _minimumIndividualOddsController = TextEditingController(
      text: fillsExistingValues
          ? strategy.minimumIndividualOdds.toStringAsFixed(2)
          : '',
    );
    _maximumIndividualOddsController = TextEditingController(
      text: fillsExistingValues
          ? strategy.maximumIndividualOdds?.toStringAsFixed(2) ?? ''
          : '',
    );
    _minimumSelectionsController = TextEditingController(
      text: fillsExistingValues ? strategy.minimumSelections.toString() : '',
    );
    _maximumSelectionsController = TextEditingController(
      text: fillsExistingValues ? strategy.maximumSelections.toString() : '',
    );
    _minimumTotalOddsController = TextEditingController(
      text: fillsExistingValues
          ? strategy.minimumTotalOdds.toStringAsFixed(2)
          : '',
    );
    _maximumTotalOddsController = TextEditingController(
      text: fillsExistingValues
          ? strategy.maximumTotalOdds?.toStringAsFixed(2) ?? ''
          : '',
    );
    _isActive = strategy.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minimumIndividualOddsController.dispose();
    _maximumIndividualOddsController.dispose();
    _minimumSelectionsController.dispose();
    _maximumSelectionsController.dispose();
    _minimumTotalOddsController.dispose();
    _maximumTotalOddsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  'Modifier la stratégie',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('save-strategy-button'),
                onPressed: _submit,
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              _NumberedStrategySection(
                number: 1,
                title: 'Nom et statut',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('strategy-name-field'),
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nom',
                              hintText: 'Ex. Ticket du week-end',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            Text(
                              _isActive ? 'Active' : 'Inactive',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (widget.canDelete) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(const _StrategyEditorResult.deleted()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.error,
                            side: BorderSide(color: colorScheme.error),
                          ),
                          child: const Text('Supprimer la stratégie'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _NumberedStrategySection(
                number: 2,
                title: 'Cotes individuelles',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _CompactStrategyField(
                            key: const ValueKey(
                              'minimum-individual-odds-field',
                            ),
                            controller: _minimumIndividualOddsController,
                            label: 'Min pick (0 = aucun)',
                            hintText: _defaultMinimumIndividualOdds
                                .toStringAsFixed(2),
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactStrategyField(
                            key: const ValueKey(
                              'maximum-individual-odds-field',
                            ),
                            controller: _maximumIndividualOddsController,
                            label: 'Max pick',
                            hintText:
                                _defaultMaximumIndividualOdds?.toStringAsFixed(
                                  2,
                                ) ??
                                'Ouverte',
                            onChanged: (_) => setState(() {
                              _maximumIndividualOddsTouched = true;
                            }),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _NumberedStrategySection(
                number: 3,
                title: 'Sélections',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _CompactStrategyField(
                            key: const ValueKey('minimum-selections-field'),
                            controller: _minimumSelectionsController,
                            label: 'Minimum',
                            hintText: _defaultMinimumSelections.toString(),
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactStrategyField(
                            key: const ValueKey('maximum-selections-field'),
                            controller: _maximumSelectionsController,
                            label: 'Maximum',
                            hintText: _defaultMaximumSelections.toString(),
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _selectionSummary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _NumberedStrategySection(
                number: 4,
                title: 'Cote totale',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _CompactStrategyField(
                            key: const ValueKey('minimum-total-odds-field'),
                            controller: _minimumTotalOddsController,
                            label: 'Minimum',
                            hintText: _defaultMinimumTotalOdds.toStringAsFixed(
                              2,
                            ),
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactStrategyField(
                            key: const ValueKey('maximum-total-odds-field'),
                            controller: _maximumTotalOddsController,
                            label: 'Maximum',
                            hintText:
                                _defaultMaximumTotalOdds?.toStringAsFixed(2) ??
                                'Ouverte',
                            onChanged: (_) => setState(() {
                              _maximumTotalOddsTouched = true;
                            }),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _StrategySummaryBox(
                summary: _strategySummary,
                validationMessage: _validationMessage,
                isValid: _canSave,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  String get _selectionSummary {
    final minimum = _minimumSelections;
    final maximum = _maximumSelections;
    if (minimum == null || maximum == null || minimum <= 0 || maximum <= 0) {
      return 'Indiquez le nombre de sélections attendu.';
    }
    if (minimum == maximum) {
      return '$minimum sélection${minimum > 1 ? 's' : ''} par ticket.';
    }

    return 'Entre $minimum et $maximum sélections par ticket.';
  }

  String get _selectionRangePhrase {
    final minimum = _minimumSelections;
    final maximum = _maximumSelections;
    if (minimum == null || maximum == null) {
      return '— sélection';
    }
    if (minimum == maximum) {
      return '$minimum sélection${minimum > 1 ? 's' : ''}';
    }

    return '$minimum à $maximum sélections';
  }

  String get _strategySummary {
    final name = _nameController.text.trim().isEmpty
        ? 'cette stratégie'
        : _nameController.text.trim();
    final totalMaximum = _maximumTotalOdds;
    final totalRange = totalMaximum == null
        ? 'à partir de ${_minimumTotalOdds?.toStringAsFixed(2) ?? '—'}'
        : 'entre ${_minimumTotalOdds?.toStringAsFixed(2) ?? '—'} et ${totalMaximum.toStringAsFixed(2)}';
    final individualMaximum = _maximumIndividualOdds;
    final individualRange = individualMaximum == null
        ? 'à partir de ${_minimumIndividualOdds?.toStringAsFixed(2) ?? '—'}'
        : 'entre ${_minimumIndividualOdds?.toStringAsFixed(2) ?? '—'} et ${individualMaximum.toStringAsFixed(2)}';

    return 'Avec $name, Lector cherchera des tickets de $_selectionRangePhrase. '
        'Les picks devront avoir une cote individuelle $individualRange, '
        'pour une cote totale $totalRange.';
  }

  String? get _validationMessage {
    if (_nameController.text.trim().isEmpty) {
      return 'Donnez un nom à votre stratégie.';
    }
    if (_minimumIndividualOdds == null) {
      return 'Indiquez une cote individuelle minimum.';
    }
    if (_minimumIndividualOdds! < 0) {
      return 'La cote individuelle minimum ne peut pas être négative.';
    }
    if (_maximumIndividualOdds != null &&
        _maximumIndividualOdds! < _minimumIndividualOdds!) {
      return 'La cote individuelle maximum doit être supérieure au minimum.';
    }
    if (_minimumSelections == null ||
        _maximumSelections == null ||
        _minimumSelections! <= 0 ||
        _maximumSelections! <= 0) {
      return 'Indiquez un nombre de sélections valide.';
    }
    if (_minimumSelections! > _maximumSelections!) {
      return 'Le maximum de sélections doit être supérieur au minimum.';
    }
    if (_minimumTotalOdds == null || _minimumTotalOdds! < 1) {
      return 'Indiquez une cote totale minimum valide.';
    }
    if (_maximumTotalOdds != null && _maximumTotalOdds! < _minimumTotalOdds!) {
      return 'La cote totale maximum doit être supérieure au minimum.';
    }

    final strategy = _currentDraftStrategy;
    if (!strategy.hasMathematicallyPossibleTicket) {
      return 'Cette stratégie ne peut produire aucun ticket : ajustez les cotes individuelles, le nombre de sélections ou la cote totale recherchée.';
    }

    return null;
  }

  bool get _canSave {
    return _validationMessage == null;
  }

  double get _defaultMinimumIndividualOdds {
    return widget.strategy.minimumIndividualOdds;
  }

  double? get _defaultMaximumIndividualOdds {
    return widget.strategy.maximumIndividualOdds;
  }

  int get _defaultMinimumSelections => widget.strategy.minimumSelections;

  int get _defaultMaximumSelections => widget.strategy.maximumSelections;

  double get _defaultMinimumTotalOdds => widget.strategy.minimumTotalOdds;

  double? get _defaultMaximumTotalOdds => widget.strategy.maximumTotalOdds;

  double? get _minimumIndividualOdds {
    final value = _doubleFrom(_minimumIndividualOddsController);
    return value ?? _defaultMinimumIndividualOdds;
  }

  double? get _maximumIndividualOdds {
    final value = _maximumIndividualOddsController.text
        .replaceAll(',', '.')
        .trim();
    if (value.isEmpty) {
      return _maximumIndividualOddsTouched ||
              _minimumIndividualOddsController.text.trim().isNotEmpty
          ? null
          : _defaultMaximumIndividualOdds;
    }

    return double.tryParse(value);
  }

  int? get _minimumSelections {
    final value = int.tryParse(_minimumSelectionsController.text.trim());
    return value ?? _defaultMinimumSelections;
  }

  int? get _maximumSelections {
    final value = int.tryParse(_maximumSelectionsController.text.trim());
    return value ?? _defaultMaximumSelections;
  }

  double? get _minimumTotalOdds {
    final value = _doubleFrom(_minimumTotalOddsController);
    return value ?? _defaultMinimumTotalOdds;
  }

  double? get _maximumTotalOdds {
    final value = _maximumTotalOddsController.text.replaceAll(',', '.').trim();
    if (value.isEmpty) {
      return _maximumTotalOddsTouched ||
              _minimumTotalOddsController.text.trim().isNotEmpty
          ? null
          : _defaultMaximumTotalOdds;
    }

    return double.tryParse(value);
  }

  double? _doubleFrom(TextEditingController controller) {
    return double.tryParse(controller.text.replaceAll(',', '.').trim());
  }

  TicketStrategy get _currentDraftStrategy {
    return widget.strategy.copyWith(
      name: _nameController.text.trim().isEmpty
          ? widget.strategy.name
          : _nameController.text.trim(),
      isActive: _isActive,
      pickTypes: _derivedPickTypes,
      minimumIndividualOdds: _minimumIndividualOdds,
      maximumIndividualOdds: _maximumIndividualOdds,
      clearsMaximumIndividualOdds: _maximumIndividualOdds == null,
      minimumSelections: _minimumSelections,
      maximumSelections: _maximumSelections,
      minimumTotalOdds: _minimumTotalOdds,
      maximumTotalOdds: _maximumTotalOdds,
      clearsMaximumTotalOdds: _maximumTotalOdds == null,
      minimumIndividualOddsIsUserDefined:
          _minimumIndividualOddsController.text.trim().isNotEmpty ||
          widget.strategy.minimumIndividualOddsIsUserDefined,
    );
  }

  List<PickType> get _derivedPickTypes {
    return TicketStrategy.pickTypesForIndividualOdds(
      _minimumIndividualOdds ?? _defaultMinimumIndividualOdds,
      _maximumIndividualOdds,
    );
  }

  void _submit() {
    if (!_canSave) {
      setState(() {});
      return;
    }

    _save();
  }

  void _save() {
    final now = DateTime.now().toUtc();
    Navigator.of(context).pop(
      _StrategyEditorResult.saved(
        widget.strategy.copyWith(
          name: _nameController.text.trim().isEmpty
              ? widget.strategy.name
              : _nameController.text.trim(),
          isActive: _isActive,
          pickTypes: _derivedPickTypes,
          minimumIndividualOdds: _minimumIndividualOdds,
          maximumIndividualOdds: _maximumIndividualOdds,
          clearsMaximumIndividualOdds: _maximumIndividualOdds == null,
          minimumSelections: _minimumSelections,
          maximumSelections: _maximumSelections,
          minimumTotalOdds: _minimumTotalOdds,
          maximumTotalOdds: _maximumTotalOdds,
          clearsMaximumTotalOdds: _maximumTotalOdds == null,
          minimumIndividualOddsIsUserDefined:
              _minimumIndividualOddsController.text.trim().isNotEmpty ||
              widget.strategy.minimumIndividualOddsIsUserDefined,
          updatedAt: now,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _CompactStrategyField extends StatelessWidget {
  const _CompactStrategyField({
    required super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.onChanged,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _NumberedStrategySection extends StatelessWidget {
  const _NumberedStrategySection({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 28,
                    child: Center(
                      child: Text(
                        number.toString(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _StrategySummaryBox extends StatelessWidget {
  const _StrategySummaryBox({
    required this.summary,
    required this.validationMessage,
    required this.isValid,
  });

  final String summary;
  final String? validationMessage;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warning = context.semantic.warning;
    final color = isValid ? colorScheme.primary : warning;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isValid
                  ? Icons.auto_awesome_rounded
                  : Icons.warning_amber_rounded,
              color: color,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isValid
                        ? 'Votre stratégie en résumé'
                        : 'Stratégie à ajuster',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    validationMessage ?? summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isValid ? colorScheme.onSurfaceVariant : warning,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSummaryScreen extends StatelessWidget {
  const _OnboardingSummaryScreen({
    required this.profile,
    required this.questions,
    required this.strategies,
    required this.onEditQuestion,
    required this.onBack,
    required this.onConfirm,
    this.onCancel,
  });

  final DecisionProfile profile;
  final List<OnboardingQuestion> questions;
  final List<TicketStrategy> strategies;
  final ValueChanged<int> onEditQuestion;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                children: [
                  _OnboardingTopBar(
                    canGoBack: true,
                    onBack: onBack,
                    onCancel: onCancel,
                  ),
                  const SizedBox(height: 18),
                  const _StepIndicator(currentIndex: 3, totalCount: 4),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  Text(
                    'Récapitulatif',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vérifiez vos préférences avant de terminer la configuration de votre profil.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final indexedQuestion in questions.indexed)
                    _SummarySection(
                      title: _summaryTitle(indexedQuestion.$2.id),
                      icon: _summaryIcon(indexedQuestion.$2.id),
                      countLabel: indexedQuestion.$2.id == 'ticket_strategies'
                          ? _strategyCountLabel()
                          : _countLabel(indexedQuestion.$2),
                      values: indexedQuestion.$2.id == 'ticket_strategies'
                          ? _strategyLabels(context)
                          : _labelsForQuestion(indexedQuestion.$2, context),
                      onTap: () => onEditQuestion(indexedQuestion.$1),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onConfirm,
                  child: const Text('Terminer la configuration'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onBack, child: const Text('Retour')),
            ],
          ),
        ),
      ),
    );
  }

  String _summaryTitle(String questionId) {
    return switch (questionId) {
      'competitions' => 'Compétitions suivies',
      'markets' => 'Marchés joués',
      'opportunity_profiles' => 'Profils d’opportunités',
      'ticket_strategies' => 'Stratégies de tickets',
      _ => questionId,
    };
  }

  IconData _summaryIcon(String questionId) {
    return switch (questionId) {
      'competitions' => Icons.flag_outlined,
      'markets' => Icons.track_changes_rounded,
      'opportunity_profiles' => Icons.star_rounded,
      'ticket_strategies' => Icons.style_outlined,
      _ => Icons.check_circle_outline_rounded,
    };
  }

  String _countLabel(OnboardingQuestion question) {
    final answer = profile.answerFor(question.id);
    return switch (question.id) {
      'competitions' =>
        '${answer.orderedOptionIds.length} championnat(s) sélectionné(s)',
      'markets' => '${answer.orderedOptionIds.length} marché(s) sélectionné(s)',
      'opportunity_profiles' =>
        '${answer.orderedOptionIds.length} profil(s) sélectionné(s)',
      _ => '${answer.orderedOptionIds.length} sélection(s)',
    };
  }

  String _strategyCountLabel() {
    final activeCount = strategies
        .where((strategy) => strategy.isActive)
        .length;
    if (strategies.isEmpty) {
      return 'Aucune stratégie créée';
    }
    return '$activeCount stratégie(s) active(s)';
  }

  List<String> _labelsForQuestion(
    OnboardingQuestion question,
    BuildContext context,
  ) {
    final locale = Localizations.localeOf(context);
    final answer = profile.answerFor(question.id);
    if (answer.orderedOptionIds.isEmpty) {
      return const ['Aucune sélection'];
    }

    return [
      for (final optionId in answer.orderedOptionIds)
        question.options
            .firstWhere((option) => option.id == optionId)
            .label
            .resolve(locale),
    ];
  }

  List<String> _strategyLabels(BuildContext context) {
    if (strategies.isEmpty) {
      return const ['Aucune stratégie créée'];
    }

    return [
      for (final strategy in strategies)
        '${strategy.name} · ${strategy.isActive ? 'active' : 'inactive'} · ${strategy.minimumSelections}-${strategy.maximumSelections} sélections',
    ];
  }
}

class _OnboardingCompletedScreen extends StatelessWidget {
  const _OnboardingCompletedScreen({
    required this.onExplore,
    required this.onEditProfile,
  });

  final VoidCallback onExplore;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        child: SizedBox.square(
                          dimension: 94,
                          child: Icon(
                            Icons.check_rounded,
                            color: colorScheme.primary,
                            size: 54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Votre profil est prêt !',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Lector va maintenant rechercher les meilleures opportunités selon vos préférences.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _NextStepLine(
                                icon: Icons.star_rounded,
                                text:
                                    'Consultez “Pour moi” pour découvrir vos opportunités personnalisées.',
                              ),
                              SizedBox(height: 12),
                              _NextStepLine(
                                icon: Icons.style_outlined,
                                text:
                                    'Créez ou ajustez vos stratégies de tickets à tout moment.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onExplore,
                          child: const Text('Accéder à mes opportunités'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: onEditProfile,
                        child: const Text('Modifier mes préférences'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.icon,
    required this.countLabel,
    required this.values,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String countLabel;
  final List<String> values;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        countLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final value in values.take(5))
                            _SummaryValueChip(label: value),
                          if (values.length > 5)
                            _SummaryValueChip(label: '+${values.length - 5}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Modifier',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryValueChip extends StatelessWidget {
  const _SummaryValueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.tight),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NextStepLine extends StatelessWidget {
  const _NextStepLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
