import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_service.dart';

/// The bottom banner, shown from [AdService.adsFromLevel] onwards.
///
/// It reserves its height only once an ad has actually loaded, so the game
/// layout never shows an empty grey strip — and on desktop/web it renders
/// nothing at all. Nothing is even requested from AdMob until the player has
/// progressed past the ad-free onboarding levels.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  // A banner that fails once must not stay blank for the rest of the
  // session, so failures back off and try again instead of giving up.
  static const _maxAttempts = 5;
  static const _backoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  BannerAd? _ad;
  bool _loaded = false;
  int _attempts = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    AdService.instance.adsUnlocked.addListener(_onGateChanged);
    _maybeLoad();
  }

  /// The gate opens mid-session, the moment the player finishes level 3, so
  /// the banner has to start itself rather than only being checked at build.
  void _onGateChanged() {
    _maybeLoad();
    if (mounted) setState(() {});
  }

  void _maybeLoad() {
    if (!AdIds.supported || _ad != null) return;
    if (!AdService.instance.adsUnlocked.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _scheduleRetry() {
    if (_attempts >= _maxAttempts) {
      debugPrint('Banner: giving up after $_attempts attempts.');
      return;
    }
    final delay = _backoff[_attempts.clamp(0, _backoff.length - 1)];
    _attempts++;
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (mounted) _maybeLoad();
    });
  }

  Future<void> _load() async {
    if (!mounted || _ad != null) return;
    final width = MediaQuery.of(context).size.width.truncate();

    // Anchored adaptive is the size Google intends for a banner pinned to a
    // screen edge. The inline adaptive size used before is meant for banners
    // inside scrolling content and fills noticeably worse in this position.
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;
    if (size == null) {
      debugPrint('Banner: could not resolve an adaptive size.');
      _scheduleRetry();
      return;
    }

    final ad = BannerAd(
      size: size,
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _attempts = 0;
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed (attempt ${_attempts + 1}): $error');
          ad.dispose();
          _ad = null;
          _scheduleRetry();
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _retry?.cancel();
    AdService.instance.adsUnlocked.removeListener(_onGateChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!AdIds.supported ||
        !AdService.instance.adsUnlocked.value ||
        ad == null ||
        !_loaded) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
