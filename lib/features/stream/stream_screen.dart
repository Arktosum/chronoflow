import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/river_repository.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_sky.dart';
import '../timeline/day_timeline_screen.dart';
import '../mako/mako_chat_screen.dart';
import 'entry_card.dart';
import 'thought_editor_screen.dart';
import 'thread_screen.dart';

class StreamScreen extends ConsumerStatefulWidget {
  const StreamScreen({super.key});

  @override
  ConsumerState<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends ConsumerState<StreamScreen> {
  Timer? _museTimer;

  @override
  void initState() {
    super.initState();
    // Mako reads the river on open and once an hour while it stays open;
    // she only speaks when she has something worth saying.
    Future.microtask(() => ref.read(makoProvider.notifier).muse());
    _museTimer = Timer.periodic(const Duration(hours: 1),
        (_) => ref.read(makoProvider.notifier).muse());
  }

  @override
  void dispose() {
    _museTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, int entryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RiverColors.surfaceRaised,
        title: const Text('Let this drop go?'),
        content: const Text('This thought will leave the river forever.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(repositoryProvider).deleteEntry(entryId);
      ref.refreshRiver();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(streamProvider);
    final continuedIds =
        ref.watch(continuedIdsProvider).asData?.value ?? const <int>{};
    final mako = ref.watch(makoProvider);

    return NightSkyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('THE RIVER'),
          actions: [
            IconButton(
              icon: Icon(Icons.sensors_rounded,
                  color: mako.thinking
                      ? RiverColors.purple
                      : RiverColors.textSecondary),
              tooltip: 'Talk to Mako',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MakoChatScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.view_day_outlined,
                  color: RiverColors.textSecondary),
              tooltip: 'Timeline lens',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DayTimelineScreen()),
              ),
            ),
          ],
        ),
        body: stream.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: RiverColors.cyan),
          ),
          error: (e, _) => Center(
            child: Text('Something snagged: $e',
                style: const TextStyle(color: RiverColors.textSecondary)),
          ),
          data: (entries) {
            // Newest at the top: open the app, meet your latest thought.
            return ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 110),
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RiverHeader(entries: entries),
                      if (mako.thinking) const _MakoThinking(),
                    ],
                  );
                }
                final item = entries[index - 1];
                final prev = index > 1 ? entries[index - 2] : null;
                final showDate = prev == null ||
                    !DateUtils.isSameDay(
                        prev.entry.createdAt, item.entry.createdAt);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDate) _DateRipple(item.entry.createdAt),
                    EntryCard(
                      item: item,
                      isContinued: continuedIds.contains(item.entry.id),
                      onThreadTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ThreadScreen(entryId: item.entry.id!),
                        ),
                      ),
                      onTap: item.entry.isCheckIn
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ThoughtEditorScreen(
                                      existing: item.entry),
                                  fullscreenDialog: true,
                                ),
                              ),
                      onLongPress: () =>
                          _confirmDelete(context, ref, item.entry.id!),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Mako's presence while she reads and thinks — a soft violet pulse
/// at the head of the river.
class _MakoThinking extends StatefulWidget {
  const _MakoThinking();

  @override
  State<_MakoThinking> createState() => _MakoThinkingState();
}

class _MakoThinkingState extends State<_MakoThinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 6, 20, 6),
      child: FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(
            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: const Row(
          children: [
            Icon(Icons.sensors_rounded, color: RiverColors.purple, size: 15),
            SizedBox(width: 8),
            Text(
              'mako is reading the river…',
              style: TextStyle(
                color: RiverColors.purple,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The head of the river: today, the day's pulse, and a thought from the
/// depths (random resurfacing).
class _RiverHeader extends ConsumerWidget {
  final List<EntryWithTags> entries;
  const _RiverHeader({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today =
        entries.where((e) => DateUtils.isSameDay(e.entry.createdAt, now));
    final drops =
        today.where((e) => !e.entry.isCheckIn && !e.entry.isMako).length;
    final stars = today.where((e) => e.entry.isCheckIn).length;
    final shuffle = ref.watch(shuffleProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE').format(now).toUpperCase(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: RiverColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${DateFormat('d MMMM yyyy').format(now)}  ·  '
            '$drops ${drops == 1 ? "drop" : "drops"}, $stars '
            '${stars == 1 ? "star" : "stars"} today',
            style: const TextStyle(
                color: RiverColors.textSecondary, fontSize: 12),
          ),
          shuffle.when(
            loading: () => const SizedBox(),
            error: (e, _) => const SizedBox(),
            data: (old) => old == null
                ? const SizedBox()
                : _ShuffleCard(item: old),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'The river is waiting.\nTap + and let a thought flow.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: RiverColors.textSecondary, height: 1.6),
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// A random old thought, surfaced from the depths.
class _ShuffleCard extends ConsumerWidget {
  final EntryWithTags item;
  const _ShuffleCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ThoughtEditorScreen(existing: item.entry),
          fullscreenDialog: true,
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: RiverColors.purple.withValues(alpha: 0.35)),
          boxShadow: RiverColors.glow(RiverColors.purple, strength: 0.25),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FROM THE DEPTHS · '
                    '${DateFormat('d MMM yyyy').format(item.entry.createdAt).toUpperCase()}',
                    style: const TextStyle(
                      color: RiverColors.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (item.entry.title != null)
                    Text(
                      item.entry.title!,
                      style: const TextStyle(
                        color: RiverColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    item.entry.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RiverColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.shuffle_rounded,
                  color: RiverColors.textFaint, size: 18),
              tooltip: 'Another one',
              onPressed: () => ref.invalidate(shuffleProvider),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRipple extends StatelessWidget {
  final DateTime date;
  const _DateRipple(this.date);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = DateUtils.isSameDay(date, now)
        ? 'TODAY'
        : DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))
            ? 'YESTERDAY'
            : DateFormat('EEE, d MMM yyyy').format(date).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: RiverColors.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

