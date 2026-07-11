/// One turn of a conversation with Mako — lives on its own page,
/// deliberately NOT an entry in the river.
class MakoMessage {
  final int? id;
  final DateTime createdAt;

  /// 'me' or 'mako'.
  final String role;
  final String text;

  /// When the question was about a specific thought: a short excerpt of it,
  /// frozen at ask-time so the chat still reads whole if the entry goes.
  final String? quote;

  const MakoMessage({
    this.id,
    required this.createdAt,
    required this.role,
    required this.text,
    this.quote,
  });

  bool get isMako => role == 'mako';

  Map<String, dynamic> toMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'role': role,
        'text': text,
        'quote': quote,
      };

  factory MakoMessage.fromMap(Map<String, dynamic> map) => MakoMessage(
        id: map['id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        role: map['role'] as String,
        text: map['text'] as String,
        quote: map['quote'] as String?,
      );
}
