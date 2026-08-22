import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// Owns the AdMob lifecycle: a persistent bottom banner, an interstitial
/// shown between levels, and a rewarded ad that grants an extra slot.
///
/// Every method is safe to call on any platform — on desktop/web (and when
/// an ad fails to load) it does nothing, so the game never blocks on ads.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  /// Interstitials start only from this level, so the first levels are a
  /// clean onboarding run.
  static const interstitialFromLevel = 3;

  bool _initialised = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  bool get supported => AdIds.supported;

  Future<void> init() async {
    if (_initialised || !supported) return;
    _initialised = true;
    try {
      await MobileAds.instance.initialize();
      _preloadInterstitial();
      _preloadRewarded();
    } catch (e) {
      debugPrint('AdMob init failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Interstitial — between levels, from [interstitialFromLevel] on
  // ---------------------------------------------------------------------------

  void _preloadInterstitial() {
    if (!supported || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('Interstitial failed: $error');
        },
      ),
    );
  }

  /// Shows the between-levels interstitial when one is ready and the player
  /// is past [interstitialFromLevel]. Returns true when an ad was shown.
  Future<bool> maybeShowInterstitial({required int completedLevel}) async {
    if (!supported || completedLevel < interstitialFromLevel) return false;
    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return false;
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadInterstitial();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preloadInterstitial();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show();
    } catch (e) {
      debugPrint('Interstitial show failed: $e');
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  // ---------------------------------------------------------------------------
  // Rewarded — watch on a loss to earn one extra slot
  // ---------------------------------------------------------------------------

  void _preloadRewarded() {
    if (!supported || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          debugPrint('Rewarded failed: $error');
        },
      ),
    );
  }

  /// True when the rescue offer can be shown to the player.
  bool get isRewardedReady => supported && _rewarded != null;

  /// Shows the rewarded ad. Returns true only when the reward was earned.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (!supported || ad == null) {
      _preloadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preloadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (ad, reward) => earned = true);
    } catch (e) {
      debugPrint('Rewarded show failed: $e');
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
  }

  /// Warms up a rewarded ad so the rescue offer is ready the moment a
  /// player loses.
  void prewarmRewarded() => _preloadRewarded();
}
