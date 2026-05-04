import 'package:flutter/material.dart';

class BarsLogoMark extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;

  const BarsLogoMark({
    super.key,
    this.size = 52,
    this.borderRadius = 12,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1D6FEB),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF1D6FEB).withValues(alpha: 0.40),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: CustomPaint(painter: _BarsPainter()),
    );
  }
}

class _BarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final barW = w * (16 / 120);
    final bottomY = h * (100 / 120);
    final startX = w * (22 / 120);
    final step = w * (22 / 120);
    final barHeights = [h * (28 / 120), h * (46 / 120), h * (64 / 120)];
    const opacities = [0.45, 0.75, 1.0];
    const rx = Radius.circular(2.5);

    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacities[i])
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + i * step,
            bottomY - barHeights[i],
            barW,
            barHeights[i],
          ),
          rx,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
