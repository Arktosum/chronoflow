import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/habit.dart';
import '../../providers.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'constellation_painter.dart';
import 'new_habit_sheet.dart';

class HabitDetailScreen extends ConsumerWidget {
  final HabitStatus status;
  const HabitDetailScreen({super.key, required this.status});

  Future<void> _deleteHabit(
      BuildContext context, WidgetRef ref, HabitStatus status) async {
    final habit = status.habit;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RiverColors.surfaceRaised,
        title: Text('Release ${habit.identityName}?'),
        content: const Text(
            'The promise ends, but its stars stay in your river forever.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep the promise'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Release',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (sure != true) return;

    await ref.read(repositoryProvider).deleteHabit(habit.id!);
    await NotificationService.instance.cancelHabitReminder(habit.id!);
    ref.refreshRiver();
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _editReminder(
      BuildContext context, WidgetRef ref, HabitStatus status) async {
    final habit = status.habit;
    final initial = habit.reminderMinutes != null
        ? TimeOfDay(
            hour: habit.reminderMinutes! ~/ 60,
            minute: habit.reminderMinutes! % 60)
        : const TimeOfDay(hour: 20, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    final updated = Habit(
      id: habit.id,
      tagId: habit.tagId,
      tagName: habit.tagName,
      identityName: habit.identityName,
      frequencyType: habit.frequencyType,
      timesPerWeek: habit.timesPerWeek,
      dailyTarget: habit.dailyTarget,
      reminderMinutes: picked.hour * 60 + picked.minute,
      createdAt: habit.createdAt,
      isArchived: habit.isArchived,
      colorVal: habit.colorVal,
    );
    await ref.read(repositoryProvider).updateHabit(updated);
    await NotificationService.instance.scheduleHabitReminder(updated);
    ref.refreshRiver();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Follow live state so edits and check-ins reflect immediately.
    final live = ref.watch(habitsProvider).value?.where(
          (s) => s.habit.id == status.habit.id,
        );
    final current = (live != null && live.isNotEmpty) ? live.first : status;
    final habit = current.habit;
    final color = Color(habit.colorVal);
    final days = ref.watch(checkInDaysProvider(habit.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('#${habit.tagName}'.toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: RiverColors.textSecondary),
            tooltip: 'Reshape',
            onPressed: () => showNewHabitSheet(context, existing: habit),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: RiverColors.textSecondary),
            tooltip: 'Release',
            onPressed: () => _deleteHabit(context, ref, current),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // The constellation, big
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: RiverColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: CustomPaint(
              painter: ConstellationPainter(
                seed: habit.id ?? 1,
                starCount: current.totalCheckIns,
                color: color,
                dimmed: current.streak.isDimmed,
              ),
            ),
          ),
          if (habit.identityName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'every star is a vote for “${habit.identityName}”',
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                value: '${current.streak.streakDays}',
                label: current.streak.isDimmed ? 'STREAK (DIM)' : 'STREAK',
                emoji: '🔥',
                dim: current.streak.isDimmed,
              ),
              _Stat(
                value: '${current.totalCheckIns}',
                label: 'STARS',
                emoji: '⭐',
              ),
              _Stat(
                value: '${current.todayCount}/${habit.dailyTarget}',
                label: 'TODAY',
                emoji: '☀️',
              ),
            ],
          ),
          const SizedBox(height: 28),

          const Text(
            'THE LAST 17 WEEKS',
            style: TextStyle(
              color: RiverColors.textSecondary,
              fontSize: 12,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          days.when(
            loading: () => const SizedBox(height: 100),
            error: (e, _) => Text('$e'),
            data: (checkIns) => _Heatmap(checkIns: checkIns, color: color),
          ),
          const SizedBox(height: 28),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined,
                color: RiverColors.cyan),
            title: Text(
              habit.reminderMinutes == null
                  ? 'No reminder set'
                  : 'Reminder at '
                      '${(habit.reminderMinutes! ~/ 60).toString().padLeft(2, '0')}:'
                      '${(habit.reminderMinutes! % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(color: RiverColors.textPrimary),
            ),
            subtitle: Text(
              habit.isDaily
                  ? (habit.dailyTarget > 1
                      ? '${habit.dailyTarget}× every day'
                      : 'Every day')
                  : '${habit.timesPerWeek}× per week',
              style: const TextStyle(color: RiverColors.textSecondary),
            ),
            trailing: const Icon(Icons.edit, color: RiverColors.textSecondary),
            onTap: () => _editReminder(context, ref, current),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final bool dim;
  const _Stat({
    required this.value,
    required this.label,
    required this.emoji,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$emoji $value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: dim ? RiverColors.flameDim : RiverColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RiverColors.textFaint,
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// GitHub-style grid: 17 weeks × 7 days, today in the bottom-right.
class _Heatmap extends StatelessWidget {
  final List<DateTime> checkIns;
  final Color color;
  const _Heatmap({required this.checkIns, required this.color});

  @override
  Widget build(BuildContext context) {
    final checked = checkIns
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Column per week; last column ends today.
    const weeks = 17;
    final startOffset = weeks * 7 - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(weeks, (w) {
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Column(
            children: List.generate(7, (d) {
              final daysAgo = startOffset - (w * 7 + d);
              final date = todayDate.subtract(Duration(days: daysAgo));
              final isFuture = date.isAfter(todayDate);
              final isChecked = checked.contains(date);
              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: isFuture
                      ? Colors.transparent
                      : isChecked
                          ? color
                          : Colors.white10,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isChecked
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 3,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
