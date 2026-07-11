import 'dart:convert';
import 'dart:ui';

/// Plutchik's eight primary emotions, each 0.0–1.0 on an entry.
class Emotion {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  const Emotion(this.key, this.label, this.emoji, this.color);
}

const List<Emotion> emotions = [
  Emotion('joy', 'Joy', '😊', Color(0xFFF4F162)),
  Emotion('trust', 'Trust', '🤝', Color(0xFF39FF88)),
  Emotion('fear', 'Fear', '😨', Color(0xFF00C9A7)),
  Emotion('surprise', 'Surprise', '😮', Color(0xFF00F0FF)),
  Emotion('sadness', 'Sadness', '😢', Color(0xFF5C7CFF)),
  Emotion('disgust', 'Disgust', '🤢', Color(0xFFB16CFF)),
  Emotion('anger', 'Anger', '😠', Color(0xFFFF5470)),
  Emotion('anticipation', 'Anticipation', '🤩', Color(0xFFFF9800)),
];

/// Encodes a mood vector, dropping zeros; null when nothing is felt.
String? encodeMood(Map<String, double> mood) {
  final filtered = {
    for (final e in mood.entries)
      if (e.value > 0) e.key: double.parse(e.value.toStringAsFixed(2)),
  };
  return filtered.isEmpty ? null : jsonEncode(filtered);
}

Map<String, double> decodeMood(String? moodJson) {
  if (moodJson == null || moodJson.isEmpty) return {};
  final raw = jsonDecode(moodJson) as Map<String, dynamic>;
  return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
}

/// The strongest emotions first — what an entry "wears" in the stream.
List<Emotion> dominantEmotions(Map<String, double> mood, {int limit = 3}) {
  final entries = mood.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries
      .take(limit)
      .map((e) => emotions.firstWhere((em) => em.key == e.key))
      .toList();
}
