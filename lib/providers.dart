import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/models/entry.dart';
import 'data/models/habit.dart';
import 'data/models/mako_message.dart';
import 'data/repositories/river_repository.dart';
import 'logic/river_digest.dart';
import 'logic/streaks.dart';
import 'logic/xp.dart';
import 'services/mako_service.dart';

final repositoryProvider = Provider<RiverRepository>((ref) {
  return RiverRepository();
});

/// The river itself, newest first.
final streamProvider = FutureProvider<List<EntryWithTags>>((ref) async {
  return ref.watch(repositoryProvider).getStream(limit: 200);
});

/// The user's one-tap feelings.
final moodPresetsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(repositoryProvider).getMoodPresets();
});

/// Every entry carrying a tag — key is `kind + name`, e.g. "#gym".
final tagEntriesProvider =
    FutureProvider.family<List<EntryWithTags>, String>((ref, key) async {
  ref.watch(streamProvider);
  final kind = key.substring(0, 1);
  final name = key.substring(1);
  return ref
      .watch(repositoryProvider)
      .getEntriesForTag(name, kind, limit: 500);
});

/// Entries with time-spans touching a given day (key must be date-only).
final daySpansProvider =
    FutureProvider.family<List<EntryWithTags>, DateTime>((ref, day) async {
  ref.watch(streamProvider); // any new drop may carry a span
  return ref.watch(repositoryProvider).getSpansForDay(day);
});

/// Entry ids that some later thought continues (thread markers in the stream).
final continuedIdsProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(streamProvider);
  return ref.watch(repositoryProvider).getContinuedEntryIds();
});

/// The full thread an entry belongs to, oldest first.
final threadProvider =
    FutureProvider.family<List<EntryWithTags>, int>((ref, entryId) async {
  ref.watch(streamProvider);
  return ref.watch(repositoryProvider).getThread(entryId);
});

/// One random old thought, refreshed on demand (the shuffle card).
final shuffleProvider = FutureProvider<EntryWithTags?>((ref) async {
  return ref.watch(repositoryProvider).getRandomOldEntry();
});

/// A habit joined with its live streak state.
class HabitStatus {
  final Habit habit;
  final StreakInfo streak;
  final int totalCheckIns;

  /// Check-ins today, against habit.dailyTarget.
  final int todayCount;

  const HabitStatus(
      this.habit, this.streak, this.totalCheckIns, this.todayCount);

  bool get doneToday => todayCount >= habit.dailyTarget;
}

final habitsProvider = FutureProvider<List<HabitStatus>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final habits = await repo.getActiveHabits();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final statuses = <HabitStatus>[];
  for (final habit in habits) {
    final checkIns = await repo.getCheckInDays(habit.id!);
    final qualifying = qualifyingDays(checkIns, habit.dailyTarget);
    statuses.add(HabitStatus(
      habit,
      computeStreak(qualifying, now),
      checkIns.length,
      countByDay(checkIns)[today] ?? 0,
    ));
  }
  return statuses;
});

/// Check-in days for one habit (detail view: heatmap + constellation).
final checkInDaysProvider =
    FutureProvider.family<List<DateTime>, int>((ref, habitId) async {
  ref.watch(habitsProvider); // recompute when a check-in changes habit state
  return ref.watch(repositoryProvider).getCheckInDays(habitId);
});

final levelProvider = FutureProvider<LevelInfo>((ref) async {
  ref.watch(habitsProvider);
  final xp = await ref.watch(repositoryProvider).getTotalXp();
  return levelForXp(xp);
});

// --- MAKO ---

final makoServiceProvider = Provider<MakoService>((ref) => MakoService());

class MakoState {
  /// She's reading / mid-think — show her presence in the stream.
  final bool thinking;

  /// A human-readable failure to show once, then clear.
  final String? error;

  const MakoState({this.thinking = false, this.error});
}

/// The conversation with Mako, oldest first (her page, not the river).
final makoChatProvider = FutureProvider<List<MakoMessage>>((ref) async {
  return ref.watch(repositoryProvider).getMakoMessages();
});

class MakoNotifier extends Notifier<MakoState> {
  @override
  MakoState build() => const MakoState();

  void clearError() => state = MakoState(thinking: state.thinking);

  Future<String> _token() async =>
      await ref.read(repositoryProvider).getMeta('mako_token') ?? '';

  /// Ask Mako something on her chat page — optionally about one specific
  /// thought. Question leads, river context follows, so she can't miss it.
  Future<void> ask(String question, {Entry? about}) async {
    if (state.thinking) return;
    final q = question.trim();
    if (q.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    String? quote;
    if (about != null) {
      final t = about.title != null ? '${about.title}: ' : '';
      final full = '$t${about.text}'.replaceAll('\n', ' ').trim();
      quote = full.length > 120 ? '${full.substring(0, 120)}…' : full;
    }
    await repo.saveMakoMessage(MakoMessage(
        createdAt: DateTime.now(), role: 'me', text: q, quote: quote));
    state = const MakoState(thinking: true);
    ref.invalidate(makoChatProvider);

    try {
      final recent = await repo.getStream(limit: 40);
      final aboutBlock = about == null
          ? ''
          : 'The specific journal thought I\'m asking about '
              '(written ${about.createdAt}):\n'
              '"${about.title != null ? "${about.title}\n" : ""}${about.text}"\n\n';
      final reply = await ref.read(makoServiceProvider).chat(
          'My question: $q\n\n'
          '$aboutBlock'
          'For context, these are my recent journal entries from the river, '
          'oldest first:\n${riverDigest(recent)}\n\n'
          'Answer my question directly and personally, drawing on the '
          'journal context above — refer to specific entries, days, or '
          'feelings when they\'re relevant.',
          token: await _token());
      await repo.saveMakoMessage(MakoMessage(
          createdAt: DateTime.now(), role: 'mako', text: reply));
      state = const MakoState();
    } on MakoException catch (e) {
      state = MakoState(error: e.message);
    } catch (_) {
      state = const MakoState(error: 'mako slipped away mid-thought');
    }
    ref.invalidate(makoChatProvider);
  }

  /// The reader: at most once an hour (on open + while the river stays
  /// open), she reads recent days and may leave a thought in the stream —
  /// only when she genuinely has something to say.
  Future<void> muse() async {
    if (state.thinking) return;
    final repo = ref.read(repositoryProvider);

    final now = DateTime.now();
    final lastRaw = await repo.getMeta('last_musing');
    final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
    if (last != null && now.difference(last) < const Duration(hours: 1)) {
      return;
    }

    final since = now.subtract(const Duration(days: 2));
    final entries = await repo.getEntriesBetween(since, now);
    final worthReading =
        entries.any((e) => !e.entry.isMako && e.entry.createdAt.isAfter(
            last ?? DateTime.fromMillisecondsSinceEpoch(0)));
    if (!worthReading) {
      await repo.setMeta('last_musing', now.toIso8601String());
      return;
    }

    state = const MakoState(thinking: true);
    try {
      final reply = await ref.read(makoServiceProvider).chat(
          'You\'re quietly reading my journal, as you do every hour or so. '
          'Recent entries, oldest first:\n${riverDigest(entries)}\n\n'
          'If something genuinely worth saying occurs to you — a pattern '
          'you noticed, a gentle nudge, a thought I\'d be glad to find in '
          'my stream — say it in a few sentences. If you have nothing '
          'worthwhile right now, reply with exactly the single word PASS.',
          token: await _token());
      final passed =
          reply.trim().toUpperCase().replaceAll('.', '') == 'PASS';
      if (!passed) {
        await repo.saveEntry(Entry(
            createdAt: DateTime.now(), text: reply, author: 'mako'));
        ref.invalidate(streamProvider);
      }
      await repo.setMeta('last_musing', now.toIso8601String());
      state = const MakoState();
    } catch (_) {
      // Quiet failure — she'll try again next hour.
      state = const MakoState();
    }
  }
}

final makoProvider =
    NotifierProvider<MakoNotifier, MakoState>(MakoNotifier.new);

/// Call after any mutation; every lens refreshes from the same source.
extension RiverInvalidate on WidgetRef {
  void refreshRiver() {
    invalidate(streamProvider);
    invalidate(habitsProvider);
  }
}
