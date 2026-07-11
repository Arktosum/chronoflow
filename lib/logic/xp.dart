/// XP & levels: the meta-game across all habits.
const int xpPerCheckIn = 10;

/// Total XP required to *reach* [level]: 0, 100, 300, 600, 1000, ...
int xpForLevel(int level) => 50 * level * (level + 1);

class LevelInfo {
  final int level;
  final int intoLevel; // XP earned within the current level
  final int levelSpan; // XP needed to cross the current level
  const LevelInfo(this.level, this.intoLevel, this.levelSpan);

  double get progress => levelSpan == 0 ? 0 : intoLevel / levelSpan;
}

LevelInfo levelForXp(int totalXp) {
  var level = 0;
  while (xpForLevel(level + 1) <= totalXp) {
    level++;
  }
  final base = xpForLevel(level);
  return LevelInfo(level, totalXp - base, xpForLevel(level + 1) - base);
}
