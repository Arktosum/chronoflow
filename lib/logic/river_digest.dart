import 'package:intl/intl.dart';

import '../data/repositories/river_repository.dart';
import 'mood.dart';

final _stamp = DateFormat('EEE d MMM HH:mm');
final _clock = DateFormat('HH:mm');

/// Renders entries as a compact plain-text digest for Mako to read —
/// chronological, one line per drop, newest kept when space runs out.
String riverDigest(List<EntryWithTags> items, {int maxChars = 4000}) {
  final sorted = [...items]
    ..sort((a, b) => a.entry.createdAt.compareTo(b.entry.createdAt));

  // Build newest-first so trimming for budget drops the oldest lines.
  final lines = <String>[];
  var used = 0;
  for (final item in sorted.reversed) {
    final line = _digestLine(item);
    if (used + line.length > maxChars && lines.isNotEmpty) break;
    lines.add(line);
    used += line.length + 1;
  }
  return lines.reversed.join('\n');
}

String _digestLine(EntryWithTags item) {
  final e = item.entry;
  final parts = <String>['[${_stamp.format(e.createdAt)}]'];

  if (e.isMako) parts.add('(mako)');
  if (e.isCheckIn) parts.add('(habit check-in)');
  if (e.spanStart != null && e.spanEnd != null) {
    parts.add('(${e.isPlanned ? "planned" : "spent"} '
        '${_clock.format(e.spanStart!)}–${_clock.format(e.spanEnd!)})');
  }
  final mood = dominantEmotions(decodeMood(e.moodJson));
  if (mood.isNotEmpty) {
    parts.add('(feeling: ${mood.map((m) => m.label).join(', ')})');
  }

  if (e.title != null) parts.add('${e.title}:');
  var text = e.text.replaceAll('\n', ' ').trim();
  if (text.length > 240) text = '${text.substring(0, 240)}…';
  if (text.isNotEmpty) parts.add(text);

  return parts.join(' ');
}
