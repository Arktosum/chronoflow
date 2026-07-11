/// One drop in the river. A thought, a feeling, a time-log, a habit check-in —
/// all the same atomic thing: something captured at a moment.
class Entry {
  final int? id;
  final DateTime createdAt;
  final String text;

  /// Optional title — some thoughts deserve a name.
  final String? title;

  /// Optional time-span this entry describes ("this was my 2–4pm").
  final DateTime? spanStart;
  final DateTime? spanEnd;

  /// 'done' or 'planned' — only meaningful when a span is set.
  final String? spanStatus;

  /// Thread: this entry continues an earlier one.
  final int? parentId;

  /// Plutchik mood vector, JSON-encoded. Null = no mood stamped.
  final String? moodJson;

  /// Set when this entry is a habit check-in.
  final int? habitId;

  /// Who spoke: null/'me' is the user; 'mako' is her voice in the stream.
  final String? author;

  const Entry({
    this.id,
    required this.createdAt,
    this.text = '',
    this.title,
    this.spanStart,
    this.spanEnd,
    this.spanStatus,
    this.parentId,
    this.moodJson,
    this.habitId,
    this.author,
  });

  bool get isCheckIn => habitId != null;
  bool get isPlanned => spanStatus == 'planned';
  bool get isMako => author == 'mako';

  Map<String, dynamic> toMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'text': text,
        'title': title,
        'span_start': spanStart?.toIso8601String(),
        'span_end': spanEnd?.toIso8601String(),
        'span_status': spanStatus,
        'parent_id': parentId,
        'mood_json': moodJson,
        'habit_id': habitId,
        'author': author,
      };

  factory Entry.fromMap(Map<String, dynamic> map) => Entry(
        id: map['id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        text: map['text'] as String? ?? '',
        title: map['title'] as String?,
        spanStart: map['span_start'] != null
            ? DateTime.parse(map['span_start'] as String)
            : null,
        spanEnd: map['span_end'] != null
            ? DateTime.parse(map['span_end'] as String)
            : null,
        spanStatus: map['span_status'] as String?,
        parentId: map['parent_id'] as int?,
        moodJson: map['mood_json'] as String?,
        habitId: map['habit_id'] as int?,
        author: map['author'] as String?,
      );
}
