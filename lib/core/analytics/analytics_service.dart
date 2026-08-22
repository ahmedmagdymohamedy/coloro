import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics wrapper.
///
/// Every call is exception-safe and a no-op until [enable] runs, so the game
/// keeps working on platforms (or in tests) where Firebase is unavailable.
///
/// Event names follow the campaign spec: per-level events (`game_lost_7`,
/// `finish_level_15`) plus an aggregate twin of each (`game_lost`,
/// `finish_level`) carrying a `level` parameter — the per-level names make
/// funnels readable at a glance, the aggregates keep the reports usable
/// once 300 levels are live.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  /// Firebase caps an app at 500 distinct event names; the campaign uses
  /// 300 `game_lost_*` + 60 `finish_level_*` + a handful of aggregates.
  static const maxPerLevelEventIndex = 300;

  void enable(FirebaseAnalytics analytics) => _analytics = analytics;

  bool get isEnabled => _analytics != null;

  /// The player opened a level.
  void gameStarted({required int level, required bool hard}) => _log(
        'game_started',
        {'level': level, 'hard': hard ? 1 : 0},
      );

  /// The player completed the picture.
  void gameWon({required int level, required double seconds}) {
    _log('game_won', {'level': level, 'seconds': seconds.round()});
    // Milestone events for every 5th level — the campaign's hard levels.
    if (level % 5 == 0 && level <= maxPerLevelEventIndex) {
      _log('finish_level_$level', {'level': level});
      _log('finish_level', {'level': level});
    }
  }

  /// The machine jammed: every slot starving.
  void gameLost({required int level, required double progress}) {
    final pct = (progress * 100).round();
    if (level <= maxPerLevelEventIndex) {
      _log('game_lost_$level', {'level': level, 'progress': pct});
    }
    _log('game_lost', {'level': level, 'progress': pct});
  }

  /// A rewarded ad was watched to earn an extra slot.
  void extraSlotEarned({required int level}) =>
      _log('extra_slot_earned', {'level': level});

  void adShown({required String format, required int level}) =>
      _log('ad_shown', {'ad_format': format, 'level': level});

  void _log(String name, Map<String, Object> params) {
    final analytics = _analytics;
    if (analytics == null) return;
    analytics.logEvent(name: name, parameters: params).catchError((Object e) {
      debugPrint('Analytics "$name" failed: $e');
    });
  }
}
