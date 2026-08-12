import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/onboarding_questionnaire.dart';
import '../../domain/decision_profile.dart';
import '../../domain/onboarding_question.dart';

class OnboardingSummaryView extends StatelessWidget {
  const OnboardingSummaryView({
    required this.profile,
    required this.questions,
    required this.onEditQuestion,
    required this.onBack,
    required this.onConfirm,
    this.onCancel,
    super.key,
  });

  final DecisionProfile profile;
  final List<OnboardingQuestion> questions;
  final ValueChanged<int> onEditQuestion;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
          children: [
            Text(
              l10n.profileSummaryEyebrow,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.profileSummaryTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileSummarySubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            for (final indexedQuestion in questions.indexed)
              _SummarySection(
                title: indexedQuestion.$2.title.resolve(locale),
                values: _labelsForQuestion(indexedQuestion.$2, context),
                onTap: () => onEditQuestion(indexedQuestion.$1),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            children: [
              if (onCancel != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(l10n.cancelButton),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: Text(l10n.backButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.confirmProfileButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _labelsForQuestion(
    OnboardingQuestion question,
    BuildContext context,
  ) {
    final answer = profile.answerFor(question.id);
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);

    if (question.id == 'ticket_odds_ranges') {
      return _compactValues([
        for (final optionId in answer.orderedOptionIds)
          answer.oddsRanges[optionId]?.format() ??
              question.options
                  .firstWhere((option) => option.id == optionId)
                  .defaultOddsRange!
                  .format(),
      ], l10n);
    }

    if (question.id == 'market_minimum_odds') {
      final marketQuestion = OnboardingQuestionnaire.questionById('markets');

      return _compactValues([
        for (final optionId in answer.orderedOptionIds)
          '${marketQuestion.options.firstWhere((option) => option.id == optionId).label.resolve(locale)} : ${(answer.marketMinimumOdds[optionId] ?? OnboardingQuestionnaire.defaultMarketMinimumOdds).toStringAsFixed(2)}',
      ], l10n);
    }

    return _compactValues([
      for (final optionId in answer.orderedOptionIds)
        question.options
            .firstWhere((option) => option.id == optionId)
            .label
            .resolve(locale),
    ], l10n);
  }

  List<String> _compactValues(List<String> values, AppLocalizations l10n) {
    if (values.isEmpty) {
      return [l10n.noSelectionLabel];
    }

    if (values.length <= 5) {
      return values;
    }

    return [...values.take(5), l10n.moreValuesLabel(values.length - 5)];
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.values,
    required this.onTap,
  });

  final String title;
  final List<String> values;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final indexedValue in values.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${indexedValue.$1 + 1}. ${indexedValue.$2}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
