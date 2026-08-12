import 'localized_label.dart';
import 'onboarding_answer.dart';

class OnboardingOption {
  const OnboardingOption({
    required this.id,
    required this.label,
    this.defaultOddsRange,
    this.isEnabled = true,
  });

  final String id;
  final LocalizedLabel label;
  final OddsRange? defaultOddsRange;
  final bool isEnabled;
}
