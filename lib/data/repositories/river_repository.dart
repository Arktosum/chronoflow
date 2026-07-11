import 'package:sqflite/sqflite.dart';

import '../database.dart';
import '../models/entry.dart';
import '../models/habit.dart';
import '../models/mako_message.dart';
import '../models/tag.dart';
import '../../logic/tag_parser.dart';

/// An entry together with its resolved tags — what the stream renders.
class EntryWithTags {
  final Entry entry;
  final List<Tag> tags;
  const EntryWithTags(this.entry, this.tags);
}

/// The single gateway to the river's data.
class RiverRepository {
  final RiverDatabase _dbHolder;
  RiverRepository([RiverDatabase? dbHolder])
      : _dbHolder = dbHolder ?? RiverDatabase.instance;

  Future<Database> get _db => _dbHolder.database;

  // --- ENTRIES ---

  /// Saves an entry, parsing tags from its text and linking them.
  Future<Entry> saveEntry(Entry entry) async {
    final db = await _db;
    final id = await db.insert('entries', entry.toMap());
    await _linkTags(id, entry.text);
    return Entry.fromMap({...entry.toMap(), 'id': id});
  }

  /// Rewrites an entry's content and relinks its tags.
  Future<void> updateEntry(Entry entry) async {
    final db = await _db;
    await db.update('entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
    await db
        .delete('entry_tags', where: 'entry_id = ?', whereArgs: [entry.id]);
    await _linkTags(entry.id!, entry.text);
  }

  Future<void> _linkTags(int entryId, String text) async {
    final db = await _db;
    for (final p in parseTags(text)) {
      final tag = await getOrCreateTag(p.name, p.kind);
      await db.insert(
        'entry_tags',
        {'entry_id': entryId, 'tag_id': tag.id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
    await db.delete('entry_tags', where: 'entry_id = ?', whereArgs: [id]);
  }

  /// Newest first. [limit]/[offset] page through the river.
  Future<List<EntryWithTags>> getStream({int limit = 100, int offset = 0}) async {
    final db = await _db;
    final rows = await db.query(
      'entries',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return _attachTags(rows.map(Entry.fromMap).toList());
  }

  Future<List<EntryWithTags>> _attachTags(List<Entry> entries) async {
    if (entries.isEmpty) return [];
    final db = await _db;
    final ids = entries.map((e) => e.id).whereType<int>().toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT et.entry_id, t.* FROM entry_tags et
      JOIN tags t ON t.id = et.tag_id
      WHERE et.entry_id IN ($placeholders)
    ''', ids);

    final byEntry = <int, List<Tag>>{};
    for (final row in rows) {
      final entryId = row['entry_id'] as int;
      (byEntry[entryId] ??= []).add(Tag.fromMap(row));
    }
    return entries
        .map((e) => EntryWithTags(e, byEntry[e.id] ?? const []))
        .toList();
  }

  /// Past entries sharing a tag — powers "related while writing".
  Future<List<EntryWithTags>> getEntriesForTag(String name, String kind,
      {int limit = 20}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT e.* FROM entries e
      JOIN entry_tags et ON et.entry_id = e.id
      JOIN tags t ON t.id = et.tag_id
      WHERE t.name = ? AND t.kind = ?
      ORDER BY e.created_at DESC
      LIMIT ?
    ''', [name.toLowerCase(), kind, limit]);
    return _attachTags(rows.map(Entry.fromMap).toList());
  }

  /// Entries whose time-span touches [day] — the timeline lens's data.
  Future<List<EntryWithTags>> getSpansForDay(DateTime day) async {
    final db = await _db;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query(
      'entries',
      where: 'span_start IS NOT NULL AND span_start < ? AND span_end > ?',
      whereArgs: [end.toIso8601String(), start.toIso8601String()],
      orderBy: 'span_start ASC',
    );
    return _attachTags(rows.map(Entry.fromMap).toList());
  }

  /// All entries created within [start, end) — the night reader's material.
  Future<List<EntryWithTags>> getEntriesBetween(
      DateTime start, DateTime end) async {
    final db = await _db;
    final rows = await db.query(
      'entries',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'created_at ASC',
    );
    return _attachTags(rows.map(Entry.fromMap).toList());
  }

  /// One random old thought for the shuffle card (older than a week, with text).
  Future<EntryWithTags?> getRandomOldEntry() async {
    final db = await _db;
    final cutoff =
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final rows = await db.rawQuery(
      "SELECT * FROM entries WHERE created_at < ? AND text != '' "
      'ORDER BY RANDOM() LIMIT 1',
      [cutoff],
    );
    if (rows.isEmpty) return null;
    final withTags = await _attachTags([Entry.fromMap(rows.first)]);
    return withTags.first;
  }

  // --- THREADS ---

  /// Ids of entries that some later thought continues — lets the stream
  /// mark thread heads without loading whole chains.
  Future<Set<int>> getContinuedEntryIds() async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT DISTINCT parent_id FROM entries WHERE parent_id IS NOT NULL');
    return rows.map((r) => r['parent_id'] as int).toSet();
  }

  /// The whole thread [entryId] belongs to, oldest first: walk up to the
  /// first thought, then gather everything that grew from it.
  Future<List<EntryWithTags>> getThread(int entryId) async {
    final db = await _db;

    var rootId = entryId;
    final visited = <int>{entryId};
    while (true) {
      final rows = await db.query('entries',
          columns: ['parent_id'], where: 'id = ?', whereArgs: [rootId]);
      if (rows.isEmpty) break;
      final parent = rows.first['parent_id'] as int?;
      if (parent == null || !visited.add(parent)) break;
      rootId = parent;
    }

    final ids = <int>{rootId};
    var frontier = [rootId];
    while (frontier.isNotEmpty && ids.length < 200) {
      final placeholders = List.filled(frontier.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT id FROM entries WHERE parent_id IN ($placeholders)',
          frontier);
      frontier =
          rows.map((r) => r['id'] as int).where(ids.add).toList();
    }

    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
        'SELECT * FROM entries WHERE id IN ($placeholders) '
        'ORDER BY created_at ASC',
        ids.toList());
    return _attachTags(rows.map(Entry.fromMap).toList());
  }

  // --- TAGS ---

  Future<Tag> getOrCreateTag(String name, String kind) async {
    final db = await _db;
    final lower = name.toLowerCase();
    final existing = await db.query(
      'tags',
      where: 'name = ? AND kind = ?',
      whereArgs: [lower, kind],
    );
    if (existing.isNotEmpty) return Tag.fromMap(existing.first);
    final tag = Tag(name: lower, kind: kind);
    final id = await db.insert('tags', tag.toMap());
    return Tag.fromMap({...tag.toMap(), 'id': id});
  }

  Future<void> updateTag(Tag tag) async {
    final db = await _db;
    await db.update('tags', tag.toMap(), where: 'id = ?', whereArgs: [tag.id]);
  }

  /// Prefix search for autosuggestion (case-insensitive; names are stored
  /// lowercase). Empty prefix returns the most recently used tags.
  Future<List<Tag>> searchTags(String kind, String prefix,
      {int limit = 6}) async {
    final db = await _db;
    final rows = prefix.isEmpty
        ? await db.rawQuery('''
            SELECT t.* FROM tags t
            JOIN entry_tags et ON et.tag_id = t.id
            WHERE t.kind = ?
            GROUP BY t.id ORDER BY MAX(et.entry_id) DESC LIMIT ?
          ''', [kind, limit])
        : await db.query(
            'tags',
            where: 'kind = ? AND name LIKE ?',
            whereArgs: [kind, '${prefix.toLowerCase()}%'],
            orderBy: 'name ASC',
            limit: limit,
          );
    return rows.map(Tag.fromMap).toList();
  }

  // --- MOOD PRESETS ---

  Future<List<Map<String, dynamic>>> getMoodPresets() async {
    final db = await _db;
    return db.query('mood_presets', orderBy: 'id ASC');
  }

  Future<void> saveMoodPreset(
      String name, String emoji, String moodJson) async {
    final db = await _db;
    await db.insert(
      'mood_presets',
      {'name': name, 'emoji': emoji, 'mood_json': moodJson},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMoodPreset(int id) async {
    final db = await _db;
    await db.delete('mood_presets', where: 'id = ?', whereArgs: [id]);
  }

  // --- HABITS ---

  Future<Habit> createHabit({
    required String tagName,
    required String identityName,
    required int colorVal,
    String frequencyType = 'daily',
    int timesPerWeek = 7,
    int dailyTarget = 1,
    int? reminderMinutes,
  }) async {
    final db = await _db;
    final tag = await getOrCreateTag(tagName, '#');
    if (tag.colorVal == null) {
      await updateTag(Tag(
        id: tag.id,
        name: tag.name,
        kind: tag.kind,
        colorVal: colorVal,
        isFavorite: true,
      ));
    }
    final habit = Habit(
      tagId: tag.id!,
      tagName: tag.name,
      identityName: identityName,
      frequencyType: frequencyType,
      timesPerWeek: timesPerWeek,
      dailyTarget: dailyTarget,
      reminderMinutes: reminderMinutes,
      createdAt: DateTime.now(),
      colorVal: colorVal,
    );
    final id = await db.insert('habits', habit.toMap());
    return Habit.fromMap({...habit.toMap(), 'id': id}, tagName: tag.name);
  }

  Future<List<Habit>> getActiveHabits() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT h.*, t.name AS tag_name FROM habits h
      JOIN tags t ON t.id = h.tag_id
      WHERE h.is_archived = 0
      ORDER BY h.created_at ASC
    ''');
    return rows
        .map((r) => Habit.fromMap(r, tagName: r['tag_name'] as String))
        .toList();
  }

  Future<void> updateHabit(Habit habit) async {
    final db = await _db;
    await db.update('habits', habit.toMap(),
        where: 'id = ?', whereArgs: [habit.id]);
  }

  /// Deletes the promise, keeps the history: past check-in entries stay in
  /// the river (their tag still colors them).
  Future<void> deleteHabit(int habitId) async {
    final db = await _db;
    await db.delete('habits', where: 'id = ?', whereArgs: [habitId]);
  }

  Future<void> setTagColor(int tagId, int colorVal) async {
    final db = await _db;
    await db.update('tags', {'color': colorVal},
        where: 'id = ?', whereArgs: [tagId]);
  }

  /// One-tap check-in: drops a (usually silent) entry into the river,
  /// tagged with the habit's tag, and earns XP.
  Future<Entry> checkInHabit(Habit habit, {String note = ''}) async {
    final text = note.isEmpty ? '#${habit.tagName}' : note;
    final entry = await saveEntry(Entry(
      createdAt: DateTime.now(),
      text: text,
      habitId: habit.id,
    ));
    await addXp(xpAmount: 10, reason: 'checkin:${habit.tagName}');
    return entry;
  }

  /// Undo today's check-in (mis-taps happen).
  Future<void> removeTodayCheckIn(Habit habit) async {
    final db = await _db;
    final start = DateTime.now();
    final dayStart =
        DateTime(start.year, start.month, start.day).toIso8601String();
    final rows = await db.query(
      'entries',
      where: 'habit_id = ? AND created_at >= ?',
      whereArgs: [habit.id, dayStart],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await deleteEntry(rows.first['id'] as int);
      await addXp(xpAmount: -10, reason: 'undo:${habit.tagName}');
    }
  }

  /// All check-in timestamps for a habit (for streaks/heatmap/constellation).
  Future<List<DateTime>> getCheckInDays(int habitId) async {
    final db = await _db;
    final rows = await db.query(
      'entries',
      columns: ['created_at'],
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((r) => DateTime.parse(r['created_at'] as String))
        .toList();
  }

  // --- MAKO CHAT ---

  Future<List<MakoMessage>> getMakoMessages({int limit = 300}) async {
    final db = await _db;
    final rows = await db.query('mako_messages',
        orderBy: 'created_at DESC', limit: limit);
    return rows.map(MakoMessage.fromMap).toList().reversed.toList();
  }

  Future<MakoMessage> saveMakoMessage(MakoMessage message) async {
    final db = await _db;
    final id = await db.insert('mako_messages', message.toMap());
    return MakoMessage.fromMap({...message.toMap(), 'id': id});
  }

  // --- META ---

  Future<String?> getMeta(String key) async {
    final db = await _db;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await _db;
    await db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- XP ---

  Future<void> addXp({required int xpAmount, required String reason}) async {
    final db = await _db;
    await db.insert('xp_events', {
      'created_at': DateTime.now().toIso8601String(),
      'amount': xpAmount,
      'reason': reason,
    });
  }

  Future<int> getTotalXp() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT SUM(amount) AS total FROM xp_events');
    return (rows.first['total'] as int?) ?? 0;
  }
}
