import 'package:flutter/material.dart';

import '../theme/app_components.dart';

const lectorBrandMarkAsset = 'assets/brand/ls-logo-mark-clean.png';
const lectorBrandLockupAsset = 'assets/brand/lector-logo-lockup-clean.png';
const lectorBrandWordmarkTextAsset =
    'assets/brand/lector-wordmark-text-clean.png';

class LectorBrandMark extends StatelessWidget {
  const LectorBrandMark({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      lectorBrandMarkAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Text(
            'LS',
            style: TextStyle(
              color: context.brand.accent,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        );
      },
    );

    return SizedBox.square(dimension: size, child: mark);
  }
}

class LectorBrandLockup extends StatelessWidget {
  const LectorBrandLockup({required this.width, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      lectorBrandLockupAsset,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LectorBrandMark(size: width * 0.42),
            SizedBox(height: width * 0.08),
            Text(
              'LECTOR SPORT',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ],
        );
      },
    );
  }
}

class LectorHeaderLockup extends StatelessWidget {
  const LectorHeaderLockup({
    this.markSize = 34,
    this.wordmarkWidth = 132,
    super.key,
  });

  final double markSize;
  final double wordmarkWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LectorBrandMark(size: markSize),
        const SizedBox(width: 8),
        Image.asset(
          lectorBrandWordmarkTextAsset,
          width: wordmarkWidth,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'LECTOR SPORT',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            );
          },
        ),
      ],
    );
  }
}
