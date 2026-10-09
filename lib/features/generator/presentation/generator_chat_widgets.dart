import 'package:flutter/material.dart';
import '../../../core/theme/app_components.dart';

/// One compact input surface for both sports and every Lector theme.
class GeneratorComposer extends StatelessWidget {
  const GeneratorComposer({
    required this.controller,
    required this.menu,
    required this.enabled,
    required this.busy,
    required this.onSend,
    required this.onVoice,
    this.onStop,
    this.hasConversation = false,
    super.key,
  });
  final TextEditingController controller;
  final Widget menu;
  final bool enabled, busy, hasConversation;
  final VoidCallback onSend;
  final VoidCallback? onVoice, onStop;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('generator-composer'),
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: context.surfaces.surface,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: context.surfaces.border.withValues(alpha: .65)),
      boxShadow: [
        BoxShadow(
          color: context.surfaces.shadow.withValues(alpha: .10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          menu,
          Expanded(
            child: TextField(
              key: const ValueKey('generator-message-input'),
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                color: context.textColors.primary,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (enabled && !busy) onSend();
              },
              decoration: InputDecoration(
                hintText: hasConversation ? 'Poursuivre…' : 'Écrivez à Hector…',
                hintStyle: TextStyle(color: context.textColors.weak),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 14,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dicter une demande',
            onPressed: enabled && !busy ? onVoice : null,
            icon: const Icon(Icons.mic_none_rounded, size: 23),
            color: context.textColors.primary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
          ),
          if (busy && onStop != null)
            IconButton.filled(
              tooltip: 'Interrompre la génération',
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: context.brand.accent,
                foregroundColor: context.brand.onAccent,
              ),
            )
          else
            IconButton.filled(
              tooltip: 'Envoyer la demande',
              onPressed: enabled && !busy && value.text.trim().isNotEmpty
                  ? onSend
                  : null,
              icon: const Icon(Icons.arrow_upward_rounded, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: context.brand.accent,
                foregroundColor: context.brand.onAccent,
                disabledBackgroundColor: context.surfaces.surfaceHover,
                disabledForegroundColor: context.textColors.disabled,
              ),
            ),
        ],
      ),
    ),
  );
}

/// The label animates; its content always describes an actual server stage.
class GeneratorActivityLabel extends StatefulWidget {
  const GeneratorActivityLabel({required this.text, super.key});
  final String text;
  @override
  State<GeneratorActivityLabel> createState() => _GeneratorActivityLabelState();
}

class _GeneratorActivityLabelState extends State<GeneratorActivityLabel>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(
      widget.text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.textColors.secondary,
        height: 1.4,
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return label;
    return AnimatedBuilder(
      animation: _animation,
      child: label,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-3 + _animation.value * 4, 0),
          end: Alignment(-1 + _animation.value * 4, 0),
          colors: [
            context.textColors.secondary,
            context.textColors.primary,
            context.textColors.secondary,
          ],
          stops: const [0, .5, 1],
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}
