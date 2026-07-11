import 'dart:math';
import 'package:flutter/material.dart';

/// Draws a habit as a constellation: one star per check-in, connected by
/// faint lines. Positions are deterministic (seeded by habit id), so the
/// same shape emerges every time and grows with each new star.
class ConstellationPainter extends CustomPainter {
  final int seed;
  final int starCount;
  final Color color;
  final bool dimmed;

  ConstellationPainter({
    required this.seed,
    required this.starCount,
    required this.color,
    this.dimmed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (starCount == 0) return;
    final rng = Random(seed);
    final alpha = dimmed ? 0.35 : 1.0;

    // Wandering path: each star steps away from the last, clamped to bounds.
    final points = <Offset>[];
    var current = Offset(
      size.width * (0.25 + rng.nextDouble() * 0.5),
      size.height * (0.25 + rng.nextDouble() * 0.5),
    );
    points.add(current);
    for (var i = 1; i < starCount; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final step = size.shortestSide * (0.10 + rng.nextDouble() * 0.15);
      current = Offset(
        (current.dx + cos(angle) * step).clamp(8.0, size.width - 8.0),
        (current.dy + sin(angle) * step).clamp(8.0, size.height - 8.0),
      );
      points.add(current);
    }

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.20 * alpha)
      ..strokeWidth = 1;
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final starPaint = Paint()..color = color.withValues(alpha: alpha);

    for (var i = 0; i < points.length; i++) {
      final isNewest = i == points.length - 1;
      final r = isNewest ? 3.5 : 1.5 + rng.nextDouble();
      canvas.drawCircle(points[i], r + 2.5, glowPaint);
      canvas.drawCircle(points[i], r, starPaint);
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter old) =>
      old.starCount != starCount ||
      old.seed != seed ||
      old.color != color ||
      old.dimmed != dimmed;
}
