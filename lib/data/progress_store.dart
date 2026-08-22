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
  static const _kNotifyAsked = 'notify_asked';

  /// Highest level the player may play (1-based).
  int get unlockedLevel => _prefs.getInt(_kUnlocked) ?? 1;

  /// How many levels the player has finished.
  int get completedCount => unlockedLevel - 1;

  bool isCompleted(int level) => level < unlockedLevel;

  bool get soundEnabled => _prefs.getBool(_kSound) ?? true;

  Future<void> setSoundEnabled(bool value) => _prefs.setBool(_kSound, value);

  /// Whether the notification explainer has already been shown. The OS prompt
  /// can only be spent once, so this card is offered once and never again —
  /// regardless of what the player answered.
  bool get notifyAsked => _prefs.getBool(_kNotifyAsked) ?? false;

  Future<void> markNotifyAsked() => _prefs.setBool(_kNotifyAsked, true);

  /// Records a finished level and unlocks the next one.
  Future<void> recordCompletion(int level) async {
    if (level + 1 > unlockedLevel) {
      await _prefs.setInt(_kUnlocked, level + 1);
    }
  }
}
