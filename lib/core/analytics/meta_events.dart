import 'package:flutter/foundation.dart';

/// Meta (Facebook) App Events — the second analytics destination.
///
/// Firebase Analytics answers "how is the game doing". Meta App Events exist
/// for a different reason: Meta's ad delivery needs to see the events it is
/// optimising toward, inside Meta's own attribution window, or an app-install
/// campaign has nothing to learn from. Both destinations therefore receive
/// the same funnel, and [AnalyticsService] is the single place that fans out
/// to them.
///
/// ## Status: wired, not yet switched on
///
/// This layer is complete and inert. It stays inert until [configure] is
/// called with a real Meta app id, because the Facebook SDK cannot function
/// without one and initialising it against a placeholder is a startup crash
/// in a release build.
///
/// Finishing it is mechanical — see
/// `marketing/docs/facebook-app-events.md` for the exact three steps.
/// Nothing else in the codebase has to change: every call site already
/// routes through here.
class MetaEvents {
  MetaEvents._();

  static final MetaEvents instance = MetaEvents._();

  MetaEventSink? _sink;

  /// Turns the destination on. Called once at startup, only when a Meta app
  /// id exists. Until then every method below is a no-op.
  void configure(MetaEventSink sink) => _sink = sink;

  bool get isEnabled => _sink != null;

  /// Meta's standard event for progression. App-install campaigns optimise
  /// against this far better than against a custom name, because Meta has a
  /// cross-advertiser prior for what "level achieved" means.
  void levelAchieved(int level) =>
      _log('fb_mobile_level_achieved', {'fb_level': level});

  /// Fires once, the first time a player finishes a level. This is the
  /// closest thing the game has to an activation signal, and it is the event
  /// an install campaign should optimise for once there is enough volume.
  void tutorialCompleted() => _log('fb_mobile_tutorial_completion', const {});

  /// A full-screen ad was shown. With ad revenue as the only revenue, this
  /// is the value event — the more of these a player generates, the more
  /// that install was worth.
  void adImpression({required String format, required int level}) =>
      _log('fb_mobile_ad_impression', {'ad_format': format, 'fb_level': level});

  /// A rewarded ad was watched to completion. The strongest single predictor
  /// of a high-value player in an ads-only game, so it is worth its own
  /// event rather than being folded into [adImpression].
  void rewardedCompleted({required int level}) =>
      _log('fb_mobile_rewarded_video_completed', {'fb_level': level});

  /// The player is still here on day one. Meta uses retention signals to
  /// find lookalikes of players who stay.
  void sessionMilestone({required int levelsCompleted}) =>
      _log('fb_mobile_session_milestone', {'fb_level': levelsCompleted});

  void _log(String name, Map<String, Object> params) {
    final sink = _sink;
    if (sink == null) return;
    try {
      sink.logEvent(name, params);
    } catch (e) {
      // A second analytics destination must never be able to break the game.
      debugPrint('Meta event "$name" failed: $e');
    }
  }
}

/// The transport Meta events go out on.
///
/// Keeping this an interface is what lets the whole funnel be written, called
/// and reasoned about before the Facebook SDK is added — and lets it be
/// tested without one.
abstract interface class MetaEventSink {
  void logEvent(String name, Map<String, Object> parameters);
}
