import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player progress and settings.
class ProgressStore {
  ProgressStore._(this._prefs);

  static ProgressStore? _instance;

  static Future<ProgressStore> load() async {
    return _instance ??= ProgressStore._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  static const _kUnlocked = 'unlocked_level';
  static const _kSound = 'sound_enabled';

  /// Highest level the player may play (1-based).
  int get unlockedLevel => _prefs.getInt(_kUnlocked) ?? 1;

  /// How many levels the player has finished.
  int get completedCount => unlockedLevel - 1;

  bool isCompleted(int level) => level < unlockedLevel;

  bool get soundEnabled => _prefs.getBool(_kSound) ?? true;

  Future<void> setSoundEnabled(bool value) => _prefs.setBool(_kSound, value);

  /// Records a finished level and unlocks the next one.
  Future<void> recordCompletion(int level) async {
    if (level + 1 > unlockedLevel) {
      await _prefs.setInt(_kUnlocked, level + 1);
    }
  }
}
