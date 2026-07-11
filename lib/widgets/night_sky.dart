import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ambient depth for the near-black void: a faint scatter of stars and a
/// whisper of violet light bleeding from the top. Static, cheap, subtle.
class NightSkyBackground extends StatelessWidget {
  final Widget child;
  final int seed;
  const NightSkyBackground({super.key, required this.child, this.seed = 7});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B0716), Color(0xFF050508), Color(0xFF050508)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
            child: CustomPaint(
              painter: _StarfieldPainter(seed),
              size: Size.infinite,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final int seed;
  _StarfieldPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    for (var i = 0; i < 90; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = 0.4 + rng.nextDouble() * 1.0;

      // Mostly faint white dust; the occasional neon mote.
      final roll = rng.nextDouble();
      final Color color;
      if (roll > 0.96) {
        color = RiverColors.cyan.withValues(alpha: 0.35);
      } else if (roll > 0.92) {
        color = RiverColors.purple.withValues(alpha: 0.35);
      } else {
        color = Colors.white.withValues(alpha: 0.05 + rng.nextDouble() * 0.12);
      }
      canvas.drawCircle(Offset(dx, dy), r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.seed != seed;
}
