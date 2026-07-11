import 'package:flutter_test/flutter_test.dart';
import 'package:life_gui/data/models/entry.dart';
import 'package:life_gui/data/repositories/river_repository.dart';
import 'package:life_gui/logic/river_digest.dart';
import 'package:life_gui/logic/streaks.dart';
import 'package:life_gui/logic/tag_parser.dart';
import 'package:life_gui/logic/xp.dart';

void main() {
  group('tag parser', () {
    test('finds # and @ tags, lowercased and deduped', () {
      final tags = parseTags('Went to the #Gym with @Amma, loved the #gym');
      expect(tags, contains(const ParsedTag('#', 'gym')));
      expect(tags, contains(const ParsedTag('@', 'amma')));
      expect(tags.length, 2);
    });

    test('ignores plain text and emails-like fragments', () {
      expect(parseTags('no tags here at all'), isEmpty);
    });
  });

  group('streaks (never miss twice)', () {
    final now = DateTime(2026, 7, 11, 15); // arbitrary afternoon

    DateTime day(int daysAgo) => DateTime(2026, 7, 11 - daysAgo);

    test('empty history = no streak', () {
      final s = computeStreak([], now);
      expect(s.streakDays, 0);
      expect(s.checkedToday, false);
    });

    test('consecutive days count', () {
      final s = computeStreak([day(0), day(1), day(2)], now);
      expect(s.streakDays, 3);
      expect(s.checkedToday, true);
      expect(s.isDimmed, false);
    });

    test('one missed day is forgiven', () {
      // checked today, missed yesterday, checked the day before
      final s = computeStreak([day(0), day(2), day(3)], now);
      expect(s.streakDays, 3);
    });

    test('yesterday missed + today unchecked = dimmed, streak alive', () {
      final s = computeStreak([day(1), day(2)], now);
      expect(s.streakDays, 2);
      expect(s.isDimmed, true);
      expect(s.checkedToday, false);
    });

    test('two full missed days kill the streak', () {
      final s = computeStreak([day(2), day(3)], now);
      expect(s.streakDays, 0);
    });

    test('two consecutive missed days inside history break the chain', () {
      // today, then a 3-day gap back to older run
      final s = computeStreak([day(0), day(3), day(4)], now);
      expect(s.streakDays, 1);
    });

    test('duplicate same-day check-ins count once', () {
      final s = computeStreak(
          [day(0), DateTime(2026, 7, 11, 9), day(1)], now);
      expect(s.streakDays, 2);
    });
  });

  group('daily targets', () {
    test('a day only qualifies when it meets the target', () {
      final d = DateTime(2026, 7, 10);
      final checkIns = [
        d.add(const Duration(hours: 8)),
        d.add(const Duration(hours: 13)),
        DateTime(2026, 7, 11, 9), // only 1 of 3 on the 11th
      ];
      final days = qualifyingDays(checkIns, 2);
      expect(days, [DateTime(2026, 7, 10)]);
    });

    test('target 1 keeps every day', () {
      final days = qualifyingDays(
          [DateTime(2026, 7, 10, 8), DateTime(2026, 7, 11, 9)], 1);
      expect(days.length, 2);
    });
  });

  group('river digest (what mako reads)', () {
    EntryWithTags drop(DateTime at, String text,
            {String? author, String? title}) =>
        EntryWithTags(
            Entry(createdAt: at, text: text, author: author, title: title),
            const []);

    test('renders chronologically with markers', () {
      final digest = riverDigest([
        drop(DateTime(2026, 7, 11, 9), 'morning thought'),
        drop(DateTime(2026, 7, 10, 22), 'late reply', author: 'mako'),
      ]);
      final lines = digest.split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, contains('(mako)'));
      expect(lines.first, contains('late reply'));
      expect(lines.last, contains('morning thought'));
    });

    test('includes titles and truncates long text', () {
      final digest = riverDigest([
        drop(DateTime(2026, 7, 11), 'x' * 500, title: 'Big idea'),
      ]);
      expect(digest, contains('Big idea:'));
      expect(digest, contains('…'));
      expect(digest.length, lessThan(320));
    });

    test('budget keeps the newest lines', () {
      final digest = riverDigest([
        for (var i = 0; i < 50; i++)
          drop(DateTime(2026, 7, 1).add(Duration(hours: i)), 'thought $i'),
      ], maxChars: 200);
      expect(digest, contains('thought 49'));
      expect(digest, isNot(contains('thought 0 ')));
      expect(digest.length, lessThanOrEqualTo(240));
    });
  });

  group('xp / levels', () {
    test('level thresholds', () {
      expect(levelForXp(0).level, 0);
      expect(levelForXp(99).level, 0);
      expect(levelForXp(100).level, 1);
      expect(levelForXp(300).level, 2);
    });

    test('progress within a level', () {
      final info = levelForXp(150); // level 1 spans 100..300
      expect(info.level, 1);
      expect(info.intoLevel, 50);
      expect(info.levelSpan, 200);
    });
  });
}
