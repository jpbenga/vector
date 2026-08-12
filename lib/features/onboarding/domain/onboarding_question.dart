import 'localized_label.dart';
import 'onboarding_option.dart';

enum OnboardingQuestionType {
  multiSelect,
  multiSelectRanking,
  singleChoice,
  editableOddsRanges,
  marketMinimumOdds,
  scale,
  ticketStrategies,
}

class OnboardingQuestion {
  const OnboardingQuestion({
    required this.id,
    required this.position,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.options,
  });

  final String id;
  final int position;
  final LocalizedLabel title;
  final LocalizedLabel subtitle;
  final OnboardingQuestionType type;
  final List<OnboardingOption> options;
}
