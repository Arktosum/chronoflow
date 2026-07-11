import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Fresh start: new file (river.db). The old life_gui.db is left untouched.
class RiverDatabase {
  static final RiverDatabase instance = RiverDatabase._();
  RiverDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'river.db');
    return openDatabase(path, version: 5, onCreate: _create, onUpgrade: _upgrade);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE entries ADD COLUMN title TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE entries ADD COLUMN span_status TEXT');
      await db.execute(
          'ALTER TABLE habits ADD COLUMN daily_target INTEGER NOT NULL DEFAULT 1');
      await _createMoodPresets(db);
    }
    if (oldVersion < 4) {
      // Mako joins the river: entries can now carry another author's voice.
      await db.execute('ALTER TABLE entries ADD COLUMN author TEXT');
      await _createMeta(db);
    }
    if (oldVersion < 5) {
      // Conversations with Mako moved out of the river into their own page.
      await _createMakoMessages(db);
    }
  }

  Future<void> _createMakoMessages(Database db) async {
    await db.execute('''
      CREATE TABLE mako_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        role TEXT NOT NULL,
        text TEXT NOT NULL,
        quote TEXT
      )
    ''');
  }

  Future<void> _createMeta(Database db) async {
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMoodPresets(Database db) async {
    await db.execute('''
      CREATE TABLE mood_presets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        emoji TEXT NOT NULL,
        mood_json TEXT NOT NULL
      )
    ''');

    // Starter feelings — one tap each; users sculpt their own on top.
    const seeds = [
      ['Happy', '😊', '{"joy":0.8}'],
      ['Sad', '😢', '{"sadness":0.8}'],
      ['Anxious', '😬', '{"fear":0.7,"anticipation":0.6}'],
      ['Angry', '😠', '{"anger":0.8}'],
      ['Tired', '😴', '{"sadness":0.5,"disgust":0.3}'],
      ['Flow', '⚡', '{"joy":0.7,"anticipation":0.9}'],
      ['Grateful', '🥹', '{"joy":0.6,"trust":0.8}'],
      ['Excited', '🤩', '{"joy":0.8,"surprise":0.5,"anticipation":0.8}'],
    ];
    for (final s in seeds) {
      await db.insert(
        'mood_presets',
        {'name': s[0], 'emoji': s[1], 'mood_json': s[2]},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        title TEXT,
        span_start TEXT,
        span_end TEXT,
        span_status TEXT,
        parent_id INTEGER,
        mood_json TEXT,
        habit_id INTEGER,
        author TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_entries_created ON entries (created_at)');
    await db.execute('CREATE INDEX idx_entries_habit ON entries (habit_id)');

    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        kind TEXT NOT NULL,
        file_path TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        color INTEGER,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        UNIQUE(name, kind)
      )
    ''');

    await db.execute('''
      CREATE TABLE entry_tags (
        entry_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (entry_id, tag_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE links (
        from_entry_id INTEGER NOT NULL,
        to_entry_id INTEGER NOT NULL,
        PRIMARY KEY (from_entry_id, to_entry_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tag_id INTEGER NOT NULL,
        identity_name TEXT NOT NULL,
        frequency_type TEXT NOT NULL DEFAULT 'daily',
        times_per_week INTEGER NOT NULL DEFAULT 7,
        reminder_minutes INTEGER,
        created_at TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL,
        daily_target INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await _createMoodPresets(db);
    await _createMeta(db);
    await _createMakoMessages(db);

    await db.execute('''
      CREATE TABLE xp_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        amount INTEGER NOT NULL,
        reason TEXT NOT NULL
      )
    ''');
  }
}
