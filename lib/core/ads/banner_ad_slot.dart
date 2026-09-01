import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_colors.dart';
import 'ad_ids.dart';
import 'ad_service.dart';

/// The bottom banner, shown from [AdService.adsFromLevel] onwards.
///
/// Two things here are deliberate, and both came out of playtesting:
///
/// **It uses the standard 320×50 banner, not an adaptive one.** Adaptive
/// anchored earns a little more per impression, but the plugin has
/// deprecated the normal variant in favour of the *large* one — and large
/// is roughly twice the height and was eating the bottom of the play area
/// ("the banner takes a very big size"). Given the choice between a taller
/// ad and a readable board, the board wins: a banner that crowds the
/// puzzle costs more in retention than it earns in eCPM. 320×50 is also
/// the most reliably filled size there is.
///
/// **It reserves its height as soon as ads are unlocked, before any ad has
/// loaded.** It used to reserve nothing until an ad arrived, so the whole
/// game jumped upward the instant one did — "when the banner shows up
/// everything gets pushed and it's startling". The strip is now claimed up
/// front and filled in later, so the layout never moves. While it is empty
/// it paints the panel colour, so it reads as part of the machine rather
/// than a flash of blank white.
///
/// Before the gate opens it still occupies nothing at all — the ad-free
/// onboarding levels get the whole screen.
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

  /// Height used for the reservation until the real adaptive size resolves.
  /// 50 is the classic banner height and the floor anchored adaptive returns.
  static const _fallbackHeight = 50.0;

  /// Hard ceiling on the strip, so no future size change can quietly start
  /// crowding the board again. The board is the game.
  static const _maxHeight = 64.0;

  BannerAd? _ad;
  bool _loaded = false;
  double? _reservedHeight;
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

    // Fixed 320x50. Its height is known without an async lookup, so the
    // strip can be reserved on the very first build and never resizes.
    const size = AdSize.banner;
    final height = size.height.toDouble().clamp(0.0, _maxHeight);
    if (_reservedHeight != height) {
      setState(() => _reservedHeight = height);
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
          if (mounted) setState(() => _loaded = false);
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
    // Nothing at all until the player is past the ad-free onboarding levels.
    if (!AdIds.supported || !AdService.instance.adsUnlocked.value) {
      return const SizedBox.shrink();
    }

    final height = _reservedHeight ?? _fallbackHeight;
    final ad = _ad;
    return SizedBox(
      width: double.infinity,
      height: height,
      // The strip is always this tall once ads are unlocked; only its
      // contents change. That is what stops the layout jumping.
      child: ColoredBox(
        color: AppColors.panelDeep,
        child: (ad != null && _loaded)
            ? Center(
                child: SizedBox(
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
