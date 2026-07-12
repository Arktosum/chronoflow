# ChronoFlow — The River

A personal life-log for Android, built with Flutter. One stream ("the river")
holds everything you capture: thoughts, moods, time-spans, and habit
check-ins — all the same atomic entry, viewed through different lenses.

## The pieces

- **The River** — a reverse-chronological stream of drops. `#tags` and
  `@people` are parsed live from the text, colored, and tappable into their
  own pages. Thoughts can carry a title, a Plutchik mood vector, and a
  time-span; threads chain thoughts together ("continue ⟩").
- **The Sky** — habits as constellations. Each check-in lights a star;
  streaks are forgiving ("never miss twice"), and check-ins earn XP toward
  levels. Per-habit daily reminders via local notifications.
- **Timeline lens** — the same river seen as a day of hours; entries with
  time-spans become blocks, planned blocks are hollow, overdue ones glow.
- **Mako** — an AI companion (external server) with her own chat page. She
  reads recent entries about once an hour and may leave a thought in the
  stream; you can also ask her about a specific thought.
- **Backup** — ⋮ menu on the River: export the SQLite database via the
  share sheet, restore from a picked file. Android auto-backup rules cover
  the database for device backups/transfers.

## Stack

- Flutter + Riverpod, sqflite (single `river.db`, versioned migrations in
  `lib/data/database.dart`), `flutter_local_notifications`.
- Pure logic (tags, streaks, XP, mood, Mako's digest) lives in `lib/logic/`
  and is covered by `test/logic_test.dart` — run `flutter test`.

## Building

```
flutter pub get
flutter build apk --release
```

Note: `kotlin.incremental=false` in `android/gradle.properties` is required
on Windows when the pub cache and the project are on different drives.
