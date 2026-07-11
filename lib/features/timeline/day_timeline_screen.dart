import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/entry.dart';
import '../../data/repositories/river_repository.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_sky.dart';
import '../stream/thought_editor_screen.dart';

const double _hourHeight = 64;

/// The timeline lens: the same river, seen as a day of hours. Entries that
/// carry a time-span become blocks of colored light; tap a gap to fill it.
class DayTimelineScreen extends ConsumerStatefulWidget {
  const DayTimelineScreen({super.key});

  @override
  ConsumerState<DayTimelineScreen> createState() => _DayTimelineScreenState();
}

class _DayTimelineScreenState extends ConsumerState<DayTimelineScreen> {
  DateTime _day = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _openEditor({Entry? existing, int? gapHour}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => existing != null
            ? ThoughtEditorScreen(existing: existing)
            : ThoughtEditorScreen(
                initialSpanStart: _day.add(Duration(hours: gapHour!)),
                initialSpanEnd: _day.add(Duration(hours: gapHour + 1)),
              ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spans = ref.watch(daySpansProvider(_day));
    final isToday = _day == _dateOnly(DateTime.now());

    return NightSkyBackground(
      seed: 33,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: RiverColors.textSecondary),
                onPressed: () => _shift(-1),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _day = _dateOnly(DateTime.now())),
                child: Text(
                  DateFormat('EEE, d MMM').format(_day).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    fontSize: 13,
                    color: isToday
                        ? RiverColors.cyan
                        : RiverColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: RiverColors.textSecondary),
                onPressed: () => _shift(1),
              ),
            ],
          ),
        ),
        body: spans.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: RiverColors.cyan)),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) => _DayCanvas(
            day: _day,
            items: items,
            onBlockTap: (e) => _openEditor(existing: e),
            onGapTap: (hour) => _openEditor(gapHour: hour),
          ),
        ),
      ),
    );
  }
}

class _DayCanvas extends StatelessWidget {
  final DateTime day;
  final List<EntryWithTags> items;
  final void Function(Entry) onBlockTap;
  final void Function(int hour) onGapTap;

  const _DayCanvas({
    required this.day,
    required this.items,
    required this.onBlockTap,
    required this.onGapTap,
  });

  double _minutesToY(int minutes) => minutes * _hourHeight / 60;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(day, now);
    final dayEnd = day.add(const Duration(days: 1));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 110),
      child: GestureDetector(
        onTapUp: (details) {
          final hour =
              (details.localPosition.dy / _hourHeight).floor().clamp(0, 23);
          onGapTap(hour);
        },
        child: SizedBox(
          height: 24 * _hourHeight,
          child: Stack(
            children: [
              // Hour grid
              for (var h = 0; h < 24; h++)
                Positioned(
                  top: h * _hourHeight,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: RiverColors.textFaint,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(height: 1)),
                    ],
                  ),
                ),

              // Blocks of spent time
              for (final item in items)
                _buildBlock(item, dayEnd),

              // The playhead: now
              if (isToday)
                Positioned(
                  top: _minutesToY(now.hour * 60 + now.minute),
                  left: 44,
                  right: 0,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RiverColors.cyan,
                          boxShadow: RiverColors.glow(RiverColors.cyan,
                              strength: 0.6),
                        ),
                      ),
                      Expanded(
                        child: Container(
                            height: 1.2, color: RiverColors.cyan),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(EntryWithTags item, DateTime dayEnd) {
    final entry = item.entry;
    final start =
        entry.spanStart!.isBefore(day) ? day : entry.spanStart!;
    final end = entry.spanEnd!.isAfter(dayEnd) ? dayEnd : entry.spanEnd!;
    final startMins = start.difference(day).inMinutes;
    final durationMins = end.difference(start).inMinutes;
    if (durationMins <= 0) return const SizedBox();

    final tag = item.tags.isNotEmpty ? item.tags.first : null;
    final color =
        tag?.colorVal != null ? Color(tag!.colorVal!) : RiverColors.cyan;
    final label = entry.title ??
        (entry.text.isEmpty ? (tag?.display ?? '…') : entry.text);

    // Planned intentions are hollow; done time is solid light. A planned
    // block whose hour has already passed glows amber: did it happen?
    final isPlanned = entry.isPlanned;
    final isOverdue = isPlanned && entry.spanEnd!.isBefore(DateTime.now());
    final frameColor = isOverdue ? RiverColors.flame : color;

    return Positioned(
      top: _minutesToY(startMins),
      left: 60,
      right: 16,
      height: _minutesToY(durationMins).clamp(18, double.infinity),
      child: GestureDetector(
        onTap: () => onBlockTap(entry),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPlanned
                ? Colors.transparent
                : color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(8),
            border: isPlanned
                ? Border.all(
                    color: frameColor.withValues(alpha: 0.7), width: 1.2)
                : Border(
                    left: BorderSide(color: color, width: 3),
                    top: BorderSide(color: color.withValues(alpha: 0.25)),
                    right: BorderSide(color: color.withValues(alpha: 0.25)),
                    bottom:
                        BorderSide(color: color.withValues(alpha: 0.25)),
                  ),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              isOverdue
                  ? '? $label — did it happen?'
                  : isPlanned
                      ? '◇ $label'
                      : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: frameColor.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontStyle: isPlanned ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
