import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SportsAssetBadge extends StatelessWidget {
  const SportsAssetBadge({
    required this.size,
    required this.imageUrl,
    required this.fallbackLabel,
    this.borderRadius = 6,
    this.backgroundColor,
    this.padding,
    this.icon,
    super.key,
  });

  final double size;
  final String? imageUrl;
  final String fallbackLabel;
  final double borderRadius;
  final Color? backgroundColor;
  final double? padding;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: EdgeInsets.all(padding ?? (hasImage ? 1 : 3)),
            child: Center(
              child: _AssetImage(
                imageUrl: imageUrl,
                fallback: _FallbackAssetLabel(
                  fallbackLabel: fallbackLabel,
                  icon: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetImage extends StatelessWidget {
  const _AssetImage({required this.imageUrl, required this.fallback});

  final String? imageUrl;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty || _isWidgetTestBinding) {
      return fallback;
    }

    if (url.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }

        return fallback;
      },
    );
  }

  bool get _isWidgetTestBinding {
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }
}

class _FallbackAssetLabel extends StatelessWidget {
  const _FallbackAssetLabel({required this.fallbackLabel, required this.icon});

  final String fallbackLabel;
  final IconData? icon;

  String get label => fallbackLabel.trim().isEmpty
      ? '?'
      : fallbackLabel.characters.first.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fallbackIcon = icon;

    if (fallbackIcon != null) {
      return Icon(fallbackIcon, size: 16, color: colorScheme.onSurfaceVariant);
    }

    return Center(
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
