import 'dart:async';

import 'package:flutter/foundation.dart';

/// Keeps exactly one full-screen ad loaded and ready at all times.
///
/// This exists because the naive "load one at startup, reload after it is
/// dismissed" approach fails in four separate ways, each of which silently
/// ends ad revenue for the rest of the session:
///
///  1. **A failed load is never retried.** One no-fill at launch and the
///     format is dead until the app restarts.
///  2. **The refill starts too late.** Reloading only after dismissal means
///     the next request arrives before the ad does, so it is skipped — and
///     every subsequent show is one opportunity behind.
///  3. **Cached ads expire.** AdMob drops a preloaded ad after roughly an
///     hour; showing a stale one fails, and nothing notices.
///  4. **Overlapping loads.** Several call sites asking to preload at once
///     produce duplicate in-flight requests and wasted inventory.
///
/// The cache owns all four concerns so callers only ever ask two questions:
/// [isReady], and [take].
///
/// It has no AdMob dependency — the loader and disposer are injected — which
/// keeps this logic unit-testable without a device.
class FullScreenAdCache<T extends Object> {
  FullScreenAdCache({
    required this.label,
    required this.loader,
    required this.disposer,
    this.ttl = const Duration(minutes: 50),
    this.maxAttempts = 6,
    List<Duration>? backoff,
  }) : _backoff = backoff ?? _defaultBackoff;

  /// Used in log lines so the two formats are distinguishable.
  final String label;

  /// How long a loaded ad stays usable. AdMob expires preloaded ads after
  /// about an hour; staying under that avoids show-time failures.
  final Duration ttl;

  /// Consecutive failures before the cache stops retrying on its own. It
  /// still reloads whenever [warm] is called explicitly, so a level start or
  /// an app resume always revives it.
  final int maxAttempts;

  static const _defaultBackoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
  ];

  final Future<T?> Function() loader;
  final void Function(T ad) disposer;
  final List<Duration> _backoff;

  T? _ad;
  DateTime? _loadedAt;
  bool _loading = false;
  int _attempts = 0;
  Timer? _retry;
  bool _disposed = false;

  /// Exposed for logging and tests.
  int get attempts => _attempts;
  bool get isLoading => _loading;

  /// True when [take] would return an ad right now.
  bool get isReady => _peek() != null;

  /// Returns the cached ad if it exists and has not expired, discarding it
  /// and triggering a reload if it has.
  T? _peek() {
    final ad = _ad;
    if (ad == null) return null;
    final loadedAt = _loadedAt;
    if (loadedAt != null && DateTime.now().difference(loadedAt) > ttl) {
      debugPrint('$label: cached ad expired before it could be shown.');
      _ad = null;
      _loadedAt = null;
      disposer(ad);
      warm();
      return null;
    }
    return ad;
  }

  /// Hands the ready ad to the caller and **immediately** begins loading its
  /// replacement — while the ad just taken is still on screen. By the time
  /// the player dismisses it, the next one is already in flight.
  ///
  /// Returns null when nothing is ready; a reload is started either way, so
  /// a miss now makes the next opportunity more likely to succeed.
  T? take() {
    final ad = _peek();
    if (ad == null) {
      warm();
      return null;
    }
    _ad = null;
    _loadedAt = null;
    warm();
    return ad;
  }

  /// Ensures an ad is loaded or loading. Cheap and idempotent — safe to call
  /// on every level start, every app resume, and after every failure.
  void warm() {
    if (_disposed || _loading || _ad != null) return;
    _loading = true;
    _retry?.cancel();
    loader().then((ad) {
      _loading = false;
      if (_disposed) {
        if (ad != null) disposer(ad);
        return;
      }
      if (ad == null) {
        _scheduleRetry();
        return;
      }
      _attempts = 0;
      _ad = ad;
      _loadedAt = DateTime.now();
      debugPrint('$label: ready.');
    }).catchError((Object e) {
      _loading = false;
      debugPrint('$label: load threw $e');
      if (!_disposed) _scheduleRetry();
    });
  }

  void _scheduleRetry() {
    if (_disposed) return;
    if (_attempts >= maxAttempts) {
      debugPrint('$label: $_attempts consecutive failures — pausing retries '
          'until the next level start or app resume.');
      return;
    }
    final delay = _backoff[_attempts.clamp(0, _backoff.length - 1)];
    _attempts++;
    debugPrint('$label: retrying in ${delay.inSeconds}s (attempt $_attempts).');
    _retry?.cancel();
    _retry = Timer(delay, warm);
  }

  /// Clears the failure budget and tries again straight away. Called when the
  /// app returns to the foreground, where the usual cause of a long failure
  /// streak — no connectivity — has often just been resolved.
  void revive() {
    _attempts = 0;
    _retry?.cancel();
    warm();
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    final ad = _ad;
    if (ad != null) disposer(ad);
    _ad = null;
    _loadedAt = null;
  }
}
