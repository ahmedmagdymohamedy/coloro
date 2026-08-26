import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'full_screen_ad_cache.dart';

/// Owns the AdMob lifecycle: a persistent bottom banner, an interstitial
/// shown between levels, and a rewarded ad that grants an extra slot.
///
/// Inventory for both full-screen formats is managed by [FullScreenAdCache],
/// which keeps one ad loaded at all times and starts loading the replacement
/// the instant the current one is taken. This service only decides *whether*
/// an ad may show and drives the show itself.
///
/// Every method is safe to call on any platform — on desktop/web (and when
/// an ad fails to load) it does nothing, so the game never blocks on ads.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  /// No ads of any kind — banner or interstitial — until the player reaches
  /// this level. The first three levels are a clean onboarding run, and the
  /// notification opt-in at the end of level 3 gets the screen to itself.
  static const adsFromLevel = 4;

  /// Interstitials are gated per completed level; the banner is gated by
  /// [adsUnlocked]. Both start at [adsFromLevel].
  static const interstitialFromLevel = adsFromLevel;

  /// Shortest gap between two interstitials. Levels normally run longer than
  /// this, so it only ever suppresses pathological back-to-back cases (a
  /// replayed easy level, a fast win streak) where two full-screen ads in a
  /// row would feel punitive and risk an AdMob policy flag.
  static const minInterstitialGap = Duration(seconds: 30);

  /// A full-screen ad cannot be shown while one is already on screen; the
  /// second show would simply fail. Guarding here keeps the failure out of
  /// the logs and the navigation path predictable.
  bool _showing = false;
  DateTime? _lastInterstitialAt;

  /// Whether ads may show at all yet.
  ///
  /// The banner sits above every screen in [MaterialApp.builder], so it has
  /// no screen to ask about progress — it watches this instead.
  final ValueNotifier<bool> adsUnlocked = ValueNotifier<bool>(false);

  /// Opens the gate once the player has progressed far enough. Safe to call
  /// repeatedly; the notifier only fires when the value actually changes.
  void updateGate(int unlockedLevel) {
    adsUnlocked.value = unlockedLevel >= adsFromLevel;
  }

  bool _initialised = false;

  bool get supported => AdIds.supported;

  late final FullScreenAdCache<InterstitialAd> _interstitials =
      FullScreenAdCache<InterstitialAd>(
        label: 'Interstitial',
        loader: _loadInterstitial,
        disposer: (ad) => ad.dispose(),
      );

  late final FullScreenAdCache<RewardedAd> _rewardeds =
      FullScreenAdCache<RewardedAd>(
        label: 'Rewarded',
        loader: _loadRewarded,
        disposer: (ad) => ad.dispose(),
      );

  Future<void> init() async {
    if (_initialised || !supported) return;
    _initialised = true;
    try {
      await MobileAds.instance.initialize();
      prewarm();
    } catch (e) {
      debugPrint('AdMob init failed: $e');
    }
  }

  /// Ensures both full-screen formats have inventory. Called at startup and
  /// at the start of every level, so each ad has a whole level's play time to
  /// load — and so a format whose retries were exhausted gets another chance.
  void prewarm() {
    if (!supported) return;
    _interstitials.warm();
    _rewardeds.warm();
  }

  /// Called when the app returns to the foreground. Connectivity loss is the
  /// usual cause of a long failure streak, and it is usually over by now, so
  /// the failure budget is cleared rather than merely retried.
  void onAppResumed() {
    if (!supported) return;
    _interstitials.revive();
    _rewardeds.revive();
  }

  // ---------------------------------------------------------------------------
  // Loading — each returns null instead of throwing, so the cache can retry
  // ---------------------------------------------------------------------------

  Future<InterstitialAd?> _loadInterstitial() {
    final done = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: done.complete,
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial load failed: $error');
          done.complete(null);
        },
      ),
    );
    return done.future;
  }

  Future<RewardedAd?> _loadRewarded() {
    final done = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: done.complete,
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded load failed: $error');
          done.complete(null);
        },
      ),
    );
    return done.future;
  }

  // ---------------------------------------------------------------------------
  // Interstitial — between levels, from [interstitialFromLevel] on
  // ---------------------------------------------------------------------------

  bool get _tooSoonForInterstitial {
    final last = _lastInterstitialAt;
    return last != null && DateTime.now().difference(last) < minInterstitialGap;
  }

  /// Shows the between-levels interstitial when one is ready and the player
  /// is past [interstitialFromLevel]. Returns true when an ad was shown.
  ///
  /// [level] is the level being *left* — whether it was won or lost. Both
  /// are real transitions and both show an ad; a loss followed by a retry
  /// used to be the one exit from a level that never did, which is both a
  /// worse-monetised path and an inconsistent one for the player.
  ///
  /// Never throws and never hangs: the caller navigates as soon as this
  /// resolves, so a broken ad must not strand the player on a finished level.
  Future<bool> maybeShowInterstitial({required int level}) async {
    if (!supported || level < interstitialFromLevel) return false;
    if (_showing) return false;
    if (_tooSoonForInterstitial) {
      debugPrint('Interstitial: suppressed, one was shown moments ago.');
      return false;
    }

    // take() also starts loading the replacement, so a miss here still
    // improves the odds for the next level.
    final ad = _interstitials.take();
    if (ad == null) {
      debugPrint('Interstitial: nothing in inventory — refill started.');
      return false;
    }

    _showing = true;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _lastInterstitialAt = DateTime.now(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial show failed: $error');
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );

    final shown = await _guardedShow(ad.show(), done, 'Interstitial');
    _showing = false;
    return shown;
  }

  // ---------------------------------------------------------------------------
  // Rewarded — watch on a loss to earn one extra slot. Never level-gated:
  // a player who has just lost is offered the rescue whenever one is loaded.
  // ---------------------------------------------------------------------------

  /// True when the rescue offer can be shown to the player.
  bool get isRewardedReady => supported && _rewardeds.isReady;

  /// Shows the rewarded ad. Returns true only when the reward was earned.
  Future<bool> showRewarded() async {
    if (!supported || _showing) return false;
    final ad = _rewardeds.take();
    if (ad == null) {
      debugPrint('Rewarded: nothing in inventory — refill started.');
      return false;
    }

    _showing = true;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded show failed: $error');
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
      },
    );

    final result = await _guardedShow(
      ad.show(onUserEarnedReward: (_, _) => earned = true),
      done,
      'Rewarded',
    );
    _showing = false;
    return result;
  }

  /// Awaits a show, converting a throw into a false result and putting a
  /// ceiling on the wait. Without the timeout an SDK that never fires a
  /// dismissal callback would leave the caller awaiting forever — which in
  /// practice means the player stuck on the level-complete screen.
  Future<bool> _guardedShow(
    Future<void> show,
    Completer<bool> done,
    String label,
  ) async {
    try {
      await show;
    } catch (e) {
      debugPrint('$label show threw: $e');
      if (!done.isCompleted) done.complete(false);
    }
    return done.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        debugPrint('$label: no dismissal callback after 5 minutes.');
        return false;
      },
    );
  }
}
