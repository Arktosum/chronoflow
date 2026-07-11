import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';

/// Today's habits as a row of tappable check-in orbs (lives in the Sky).
/// Multi-target habits fill a progress ring tap by tap; the last tap bursts.
class HabitBar extends ConsumerWidget {
  const HabitBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);

    return habits.when(
      loading: () => const SizedBox(height: 0),
      error: (e, _) => const SizedBox(height: 0),
      data: (statuses) {
        if (statuses.isEmpty) return const SizedBox(height: 0);
        return SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: statuses.map((s) => _HabitOrb(status: s)).toList(),
          ),
        );
      },
    );
  }
}

class _HabitOrb extends ConsumerStatefulWidget {
  final HabitStatus status;
  const _HabitOrb({required this.status});

  @override
  ConsumerState<_HabitOrb> createState() => _HabitOrbState();
}

class _HabitOrbState extends ConsumerState<_HabitOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    final s = widget.status;
    final repo = ref.read(repositoryProvider);

    if (s.doneToday) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content:
              Text('Done for today ✨ (long-press to take one back)'),
        ));
      return;
    }

    final willComplete = s.todayCount + 1 >= s.habit.dailyTarget;
    if (willComplete) {
      _burst.forward(from: 0);
    }
    await repo.checkInHabit(s.habit);
    ref.refreshRiver();

    if (mounted && willComplete) {
      final who = s.habit.identityName.isNotEmpty
          ? s.habit.identityName
          : '#${s.habit.tagName}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('⭐ A star for $who — ${s.totalCheckIns + 1} now'),
        ));
    }
  }

  Future<void> _undoOne() async {
    final s = widget.status;
    if (s.todayCount == 0) return;
    await ref.read(repositoryProvider).removeTodayCheckIn(s.habit);
    ref.refreshRiver();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final color = Color(s.habit.colorVal);
    final done = s.doneToday;
    final target = s.habit.dailyTarget;
    final progress = (s.todayCount / target).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: _checkIn,
      onLongPress: _undoOne,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring (fills tap by tap)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? color.withValues(alpha: 0.22)
                          : Colors.transparent,
                      boxShadow:
                          done ? RiverColors.glow(color, strength: 0.8) : null,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(46, 46),
                    painter: _RingPainter(
                      progress: progress,
                      color: color,
                      trackColor: Colors.white12,
                    ),
                  ),
                  // The core
                  done
                      ? Icon(Icons.star_rounded, color: color, size: 24)
                      : target > 1 && s.todayCount > 0
                          ? Text(
                              '${s.todayCount}/$target',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : Icon(Icons.star_outline_rounded,
                              color: Colors.white38, size: 22),
                  // The burst
                  AnimatedBuilder(
                    animation: _burst,
                    builder: (context, _) => _burst.value == 0
                        ? const SizedBox()
                        : IgnorePointer(
                            child: CustomPaint(
                              size: const Size(90, 90),
                              painter: _BurstPainter(
                                  progress: _burst.value, color: color),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${s.habit.tagName}',
                  style: TextStyle(
                    color: done ? color : RiverColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (s.streak.streakDays > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '🔥${s.streak.streakDays}',
                    style: TextStyle(
                      fontSize: 10,
                      color: s.streak.isDimmed
                          ? RiverColors.flameDim
                          : RiverColors.flame,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  _RingPainter(
      {required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// The completion firework: a ring of light expands while eight tiny stars
/// fly outward and fade.
class _BurstPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1 - progress).clamp(0.0, 1.0);

    // Expanding ring
    final ringRadius = 12 + progress * 32;
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * fade
        ..color = color.withValues(alpha: 0.6 * fade),
    );

    // Flying sparks
    final sparkPaint = Paint()..color = color.withValues(alpha: fade);
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4 + progress * 0.6;
      final dist = 10 + Curves.easeOut.transform(progress) * 34;
      final p = center + Offset(cos(angle) * dist, sin(angle) * dist);
      final r = 2.2 * fade + 0.3;
      canvas.drawCircle(p, r + 2, glowPaint);
      canvas.drawCircle(p, r, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.color != color;
}
