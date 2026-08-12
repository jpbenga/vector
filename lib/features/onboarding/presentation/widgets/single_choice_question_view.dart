import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../domain/onboarding_option.dart';

class SingleChoiceQuestionView extends StatelessWidget {
  const SingleChoiceQuestionView({
    required this.options,
    required this.selectedOptionId,
    required this.onChanged,
    super.key,
  });

  final List<OnboardingOption> options;
  final String selectedOptionId;
  final ValueChanged<OnboardingOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChoiceTile(
              label: option.label.resolve(locale),
              isSelected: option.id == selectedOptionId,
              onTap: () => onChanged(option),
            ),
          ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
