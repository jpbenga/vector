import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/onboarding_option.dart';

class PriorityQuestionView extends StatelessWidget {
  const PriorityQuestionView({
    required this.allOptions,
    required this.selectedOptionIds,
    required this.onChanged,
    super.key,
  });

  final List<OnboardingOption> allOptions;
  final List<String> selectedOptionIds;
  final ValueChanged<List<String>> onChanged;

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

            return _PriorityTile(
              key: ValueKey(option.id),
              option: option,
              index: index,
              onRemove: () {
                onChanged([
                  for (final id in selectedOptionIds)
                    if (id != option.id) id,
                ]);
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
                _AddOptionChip(
                  option: option,
                  onPressed: () => onChanged([...selectedOptionIds, option.id]),
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
    onChanged(next);
  }

  OnboardingOption _optionById(String optionId) {
    return allOptions.firstWhere((option) => option.id == optionId);
  }
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile({
    required super.key,
    required this.option,
    required this.index,
    required this.onRemove,
  });

  final OnboardingOption option;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

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
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: CircleAvatar(
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
            title: Text(
              option.label.resolve(locale),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).removeOptionTooltip,
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
      ),
    );
  }
}

class _AddOptionChip extends StatelessWidget {
  const _AddOptionChip({required this.option, required this.onPressed});

  final OnboardingOption option;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return ActionChip(
      avatar: const Icon(Icons.add_rounded, size: 18),
      label: Text(option.label.resolve(locale)),
      onPressed: onPressed,
    );
  }
}
