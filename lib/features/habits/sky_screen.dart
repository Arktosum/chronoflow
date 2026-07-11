import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/xp.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_sky.dart';
import 'constellation_painter.dart';
import 'habit_bar.dart';
import 'habit_detail_screen.dart';

/// The night sky: every habit is a constellation that grows star by star.
class SkyScreen extends ConsumerWidget {
  const SkyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final level = ref.watch(levelProvider);

    return NightSkyBackground(
      seed: 21,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('THE SKY')),
        body: habits.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: RiverColors.purple),
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (statuses) {
            if (statuses.isEmpty) return const _EmptySky();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                const HabitBar(),
                const SizedBox(height: 12),
                level.when(
                  loading: () => const SizedBox(),
                  error: (e, _) => const SizedBox(),
                  data: (info) => _LevelCard(info: info),
                ),
                const SizedBox(height: 8),
                ...statuses.map((s) => _ConstellationCard(status: s)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final LevelInfo info;
  const _LevelCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RiverColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LEVEL ${info.level}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: RiverColors.purple,
                ),
              ),
              Text(
                '${info.intoLevel} / ${info.levelSpan} XP',
                style: const TextStyle(
                  color: RiverColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: info.progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              color: RiverColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstellationCard extends StatelessWidget {
  final HabitStatus status;
  const _ConstellationCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final habit = status.habit;
    final color = Color(habit.colorVal);
    final dimmed =
        status.streak.isDimmed ||
        (status.streak.streakDays == 0 && status.totalCheckIns > 0);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HabitDetailScreen(status: status),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        height: 150,
        decoration: BoxDecoration(
          color: RiverColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ConstellationPainter(
                  seed: habit.id ?? 1,
                  starCount: status.totalCheckIns,
                  color: color,
                  dimmed: dimmed,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${habit.tagName}'.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 13,
                    ),
                  ),
                  if (habit.identityName.isNotEmpty)
                    Text(
                      '→ ${habit.identityName}',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${status.totalCheckIns} stars · '
                    '${status.streak.streakDays > 0 ? "🔥 ${status.streak.streakDays} day streak" : "sky is quiet"}'
                    '${status.streak.isDimmed ? " · don’t miss twice!" : ""}',
                    style: const TextStyle(
                      color: RiverColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySky extends StatelessWidget {
  const _EmptySky();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.white12, size: 64),
            SizedBox(height: 16),
            Text(
              'An empty sky.\nMake a promise, and stars will follow.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RiverColors.textSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
