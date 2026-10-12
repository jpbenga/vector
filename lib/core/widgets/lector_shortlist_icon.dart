import 'package:flutter/material.dart';

/// Original collection-of-match-cards icon, aligned with the outline icon set.
class LectorShortlistIcon extends StatelessWidget {
  const LectorShortlistIcon({
    this.size = 22,
    this.color,
    this.selected = false,
    super.key,
  });
  final double size;
  final Color? color;
  final bool selected;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _CollectionPainter(
        color ??
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.onSurface,
        selected,
      ),
    ),
  );
}

class _CollectionPainter extends CustomPainter {
  const _CollectionPainter(this.color, this.selected);
  final Color color;
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(7, 3)
        ..lineTo(18, 3)
        ..quadraticBezierTo(20, 3, 20, 5)
        ..lineTo(20, 16),
      pen,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 6, 14, 16),
        const Radius.circular(2.2),
      ),
      pen,
    );
    final mark = Path();
    if (selected) {
      mark
        ..moveTo(6, 14)
        ..lineTo(9, 17)
        ..lineTo(14, 11);
    } else {
      mark
        ..moveTo(7, 14)
        ..lineTo(13, 14)
        ..moveTo(10, 11)
        ..lineTo(10, 17);
    }
    canvas.drawPath(mark, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CollectionPainter old) =>
      old.color != color || old.selected != selected;
}
