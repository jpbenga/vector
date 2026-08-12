import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../domain/onboarding_option.dart';

class ScaleQuestionView extends StatelessWidget {
  const ScaleQuestionView({
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    super.key,
  });

  final List<OnboardingOption> options;
  final int selectedValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                side: BorderSide(
                  color: option.id == selectedValue.toString()
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: () => onChanged(int.parse(option.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: option.id == selectedValue.toString()
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        child: Text(
                          option.id,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: option.id == selectedValue.toString()
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.label.resolve(locale),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
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
