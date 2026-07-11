/// A habit is a tag with a promise attached.
class Habit {
  final int? id;
  final int tagId;
  final String tagName; // denormalized for display (e.g. "meditation")

  /// The person each check-in votes for ("Calm You").
  final String identityName;

  /// 'daily' or 'weekly' (times_per_week matters only for weekly).
  final String frequencyType;
  final int timesPerWeek;

  /// Check-ins needed for a day to count ("eat well" = 3× a day).
  final int dailyTarget;

  /// Reminder as minutes after midnight; null = no reminder.
  final int? reminderMinutes;

  final DateTime createdAt;
  final bool isArchived;
  final int colorVal;

  const Habit({
    this.id,
    required this.tagId,
    required this.tagName,
    required this.identityName,
    this.frequencyType = 'daily',
    this.timesPerWeek = 7,
    this.dailyTarget = 1,
    this.reminderMinutes,
    required this.createdAt,
    this.isArchived = false,
    required this.colorVal,
  });

  bool get isDaily => frequencyType == 'daily';

  Map<String, dynamic> toMap() => {
        'id': id,
        'tag_id': tagId,
        'identity_name': identityName,
        'frequency_type': frequencyType,
        'times_per_week': timesPerWeek,
        'daily_target': dailyTarget,
        'reminder_minutes': reminderMinutes,
        'created_at': createdAt.toIso8601String(),
        'is_archived': isArchived ? 1 : 0,
        'color': colorVal,
      };

  factory Habit.fromMap(Map<String, dynamic> map, {required String tagName}) =>
      Habit(
        id: map['id'] as int?,
        tagId: map['tag_id'] as int,
        tagName: tagName,
        identityName: map['identity_name'] as String,
        frequencyType: map['frequency_type'] as String? ?? 'daily',
        timesPerWeek: map['times_per_week'] as int? ?? 7,
        dailyTarget: map['daily_target'] as int? ?? 1,
        reminderMinutes: map['reminder_minutes'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        isArchived: (map['is_archived'] as int? ?? 0) == 1,
        colorVal: map['color'] as int,
      );
}
