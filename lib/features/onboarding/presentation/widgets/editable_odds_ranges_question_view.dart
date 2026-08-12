import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/onboarding_answer.dart';
import '../../domain/onboarding_option.dart';

class EditableOddsRangesQuestionView extends StatelessWidget {
  const EditableOddsRangesQuestionView({
    required this.allOptions,
    required this.selectedOptionIds,
    required this.oddsRanges,
    required this.onChanged,
    super.key,
  });

  final List<OnboardingOption> allOptions;
  final List<String> selectedOptionIds;
  final Map<String, OddsRange> oddsRanges;
  final void Function(
    List<String> selectedOptionIds,
    Map<String, OddsRange> oddsRanges,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedOptions = [
      for (final optionId in selectedOptionIds) _optionById(optionId),
    ];
    final availableOptions = allOptions
        .where((option) => !selectedOptionIds.contains(option.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectedOptionsTitle,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: selectedOptions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorderItem: _reorder,
          itemBuilder: (context, index) {
            final option = selectedOptions[index];
            final range = oddsRanges[option.id] ?? option.defaultOddsRange!;

            return _OddsRangeTile(
              key: ValueKey(option.id),
              option: option,
              index: index,
              range: range,
              onRangeChanged: (nextRange) {
                onChanged(selectedOptionIds, {
                  ...oddsRanges,
                  option.id: nextRange,
                });
              },
              onRemove: () {
                onChanged([
                  for (final id in selectedOptionIds)
                    if (id != option.id) id,
                ], oddsRanges);
              },
            );
          },
        ),
        if (availableOptions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            l10n.availableOptionsTitle,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in availableOptions)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    oddsRanges[option.id]?.format() ??
                        option.defaultOddsRange!.format(),
                  ),
                  onPressed: () {
                    onChanged(
                      [...selectedOptionIds, option.id],
                      {
                        ...oddsRanges,
                        option.id:
                            oddsRanges[option.id] ?? option.defaultOddsRange!,
                      },
                    );
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = [...selectedOptionIds];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    onChanged(next, oddsRanges);
  }

  OnboardingOption _optionById(String optionId) {
    return allOptions.firstWhere((option) => option.id == optionId);
  }
}

class _OddsRangeTile extends StatelessWidget {
  const _OddsRangeTile({
    required super.key,
    required this.option,
    required this.index,
    required this.range,
    required this.onRangeChanged,
    required this.onRemove,
  });

  final OnboardingOption option;
  final int index;
  final OddsRange range;
  final ValueChanged<OddsRange> onRangeChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: index == 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: index == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: index == 0
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _OddsTextField(
                        label: l10n.minOddsLabel,
                        value: range.min,
                        onChanged: (value) {
                          if (value != null) {
                            onRangeChanged(
                              OddsRange(min: value, max: range.max),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OddsTextField(
                        label: l10n.maxOddsLabel,
                        value: range.max,
                        canBeEmpty: true,
                        onChanged: (value) {
                          onRangeChanged(OddsRange(min: range.min, max: value));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.removeOptionTooltip,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OddsTextField extends StatelessWidget {
  const _OddsTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.canBeEmpty = false,
  });

  final String label;
  final double? value;
  final bool canBeEmpty;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-${value ?? 'empty'}'),
      initialValue: value?.toStringAsFixed(2) ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (rawValue) {
        final normalizedValue = rawValue.replaceAll(',', '.').trim();
        if (normalizedValue.isEmpty && canBeEmpty) {
          onChanged(null);
          return;
        }

        final parsedValue = double.tryParse(normalizedValue);
        if (parsedValue != null && parsedValue > 0) {
          onChanged(parsedValue);
        }
      },
    );
  }
}
