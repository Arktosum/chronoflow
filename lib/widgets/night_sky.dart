import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Each lens has its own weather.
enum SkyFlavor {
  /// Violet whisper from the top, plain dust. The default ambience.
  neutral,

  /// The river: cyan light rising from the depths below, sparse motes.
  river,

  /// The sky: a deeper violet night with a richer starfield.
  sky,
}

/// Ambient depth for the near-black void: a faint scatter of stars and a
/// whisper of colored light. Static, cheap, subtle.
class NightSkyBackground extends StatelessWidget {
  final Widget child;
  final int seed;
  final SkyFlavor flavor;
  const NightSkyBackground({
    super.key,
    required this.child,
    this.seed = 7,
    this.flavor = SkyFlavor.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final (tint, fromBottom, starCount, accent) = switch (flavor) {
      SkyFlavor.river => (const Color(0xFF041418), true, 55, RiverColors.cyan),
      SkyFlavor.sky => (
        const Color(0xFF150B26),
        false,
        150,
        RiverColors.purple,
      ),
      SkyFlavor.neutral => (
        const Color(0xFF0B0716),
        false,
        90,
        RiverColors.purple,
      ),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: fromBottom
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                end: fromBottom ? Alignment.topCenter : Alignment.bottomCenter,
                colors: [tint, RiverColors.bg, RiverColors.bg],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: CustomPaint(
              painter: _StarfieldPainter(seed, starCount, accent),
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
  final int starCount;
  final Color accent;
  _StarfieldPainter(this.seed, this.starCount, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    for (var i = 0; i < starCount; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = 0.4 + rng.nextDouble() * 1.0;

      // Mostly faint white dust; the occasional neon mote in the lens's color.
      final roll = rng.nextDouble();
      final Color color;
      if (roll > 0.94) {
        color = accent.withValues(alpha: 0.35);
      } else if (roll > 0.92) {
        color =
            (accent == RiverColors.cyan ? RiverColors.purple : RiverColors.cyan)
                .withValues(alpha: 0.3);
      } else {
        color = Colors.white.withValues(alpha: 0.05 + rng.nextDouble() * 0.12);
      }
      canvas.drawCircle(Offset(dx, dy), r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) =>
      old.seed != seed || old.starCount != starCount || old.accent != accent;
}

/// The app's name over the lens you're looking through:
/// CHRONOFLOW above, the lens below in its accent color.
class ChronoTitle extends StatelessWidget {
  final String lens;
  final Color accent;
  const ChronoTitle({super.key, required this.lens, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'CHRONOFLOW',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            fontSize: 14,
            color: RiverColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          lens,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            fontSize: 9,
            color: accent.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
