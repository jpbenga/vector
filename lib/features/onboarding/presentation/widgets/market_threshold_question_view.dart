import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../data/onboarding_questionnaire.dart';
import '../../domain/onboarding_option.dart';

class MarketThresholdQuestionView extends StatelessWidget {
  const MarketThresholdQuestionView({
    required this.selectedMarketOptions,
    required this.minimumOddsByMarket,
    required this.onChanged,
    super.key,
  });

  final List<OnboardingOption> selectedMarketOptions;
  final Map<String, double> minimumOddsByMarket;
  final ValueChanged<Map<String, double>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    if (selectedMarketOptions.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.noSelectedMarketsMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final option in selectedMarketOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label.resolve(locale),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 112,
                      child: TextFormField(
                        key: ValueKey(
                          '${option.id}-${minimumOddsByMarket[option.id]}',
                        ),
                        initialValue:
                            (minimumOddsByMarket[option.id] ??
                                    OnboardingQuestionnaire
                                        .defaultMarketMinimumOdds)
                                .toStringAsFixed(2),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.minOddsLabel,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (rawValue) {
                          final normalizedValue = rawValue
                              .replaceAll(',', '.')
                              .trim();
                          final parsedValue = double.tryParse(normalizedValue);
                          if (parsedValue != null && parsedValue > 0) {
                            onChanged({
                              ...minimumOddsByMarket,
                              option.id: parsedValue,
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
