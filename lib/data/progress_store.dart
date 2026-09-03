import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player progress and settings.
class ProgressStore {
  ProgressStore._(this._prefs);

  static ProgressStore? _instance;

  static Future<ProgressStore> load() async {
    return _instance ??= ProgressStore._(await SharedPreferences.getInstance());
  }

  /// Drops the cached singleton so a test can start from fresh mock prefs.
  @visibleForTesting
  static void resetForTest() => _instance = null;

  final SharedPreferences _prefs;

  static const _kUnlocked = 'unlocked_level';
  static const _kSound = 'sound_enabled';
  static const _kNotifyAsked = 'notify_asked';
  static const _kSkipped = 'skipped_levels';
  static const _kStuckLevel = 'stuck_level';
  static const _kStuckLosses = 'stuck_losses';

  /// Highest level the player may play (1-based).
  int get unlockedLevel => _prefs.getInt(_kUnlocked) ?? 1;

  /// Levels the player was let past without solving them. They count as
  /// unlocked but never as finished, so the menu's check marks stay honest.
  Set<int> get _skipped =>
      (_prefs.getStringList(_kSkipped) ?? const <String>[])
          .map(int.tryParse)
          .nonNulls
          .toSet();

  bool isSkipped(int level) => _skipped.contains(level);

  /// How many levels the player has actually finished.
  int get completedCount {
    final skippedBelow = _skipped.where((l) => l < unlockedLevel).length;
    return unlockedLevel - 1 - skippedBelow;
  }

  bool isCompleted(int level) => level < unlockedLevel && !isSkipped(level);

  bool get soundEnabled => _prefs.getBool(_kSound) ?? true;

  Future<void> setSoundEnabled(bool value) => _prefs.setBool(_kSound, value);

  /// Whether the notification explainer has already been shown. The OS prompt
  /// can only be spent once, so this card is offered once and never again —
  /// regardless of what the player answered.
  bool get notifyAsked => _prefs.getBool(_kNotifyAsked) ?? false;

  Future<void> markNotifyAsked() => _prefs.setBool(_kNotifyAsked, true);

  /// Records a finished level and unlocks the next one.
  Future<void> recordCompletion(int level) async {
    // Solving a level the player had previously skipped past promotes it to
    // a real completion.
    if (isSkipped(level)) {
      await _prefs.setStringList(
        _kSkipped,
        (_skipped..remove(level)).map((l) => '$l').toList(),
      );
    }
    await clearLossStreak();
    if (level + 1 > unlockedLevel) {
      await _prefs.setInt(_kUnlocked, level + 1);
    }
  }

  // --- Being stuck -------------------------------------------------------
  //
  // Only the CURRENT run of losses is kept, not a per-level history: the
  // question this answers is "is the player stuck on the board in front of
  // them right now", and two keys answer it exactly. Winning, skipping or
  // moving to a different level all end the run.

  /// Consecutive losses on [level], 0 if the player is stuck elsewhere.
  int lossStreak(int level) =>
      _prefs.getInt(_kStuckLevel) == level ? _prefs.getInt(_kStuckLosses) ?? 0 : 0;

  /// Records a loss and returns the new streak on that level.
  Future<int> recordLoss(int level) async {
    final next = lossStreak(level) + 1;
    await _prefs.setInt(_kStuckLevel, level);
    await _prefs.setInt(_kStuckLosses, next);
    return next;
  }

  Future<void> clearLossStreak() async {
    await _prefs.remove(_kStuckLevel);
    await _prefs.remove(_kStuckLosses);
  }

  /// Lets the player past a level they could not solve, without crediting it
  /// as finished. Unlocks the next level exactly as a win would.
  Future<void> skipLevel(int level) async {
    await _prefs.setStringList(
      _kSkipped,
      (_skipped..add(level)).map((l) => '$l').toList(),
    );
    await clearLossStreak();
    if (level + 1 > unlockedLevel) {
      await _prefs.setInt(_kUnlocked, level + 1);
    }
  }
}
