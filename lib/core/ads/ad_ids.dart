import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob unit IDs.
///
/// Live units for AdMob publisher ca-app-pub-3208735875691916, used in
/// release builds; debug builds fall back to Google's test units
/// automatically (see [useTestAds]).
///
/// ┌──────────────────────────────────────────────────────────────────────┐
/// │  You also need the AdMob APP IDs (not unit IDs) declared natively —  │
/// │  a `meta-data` entry named                                           │
/// │  `com.google.android.gms.ads.APPLICATION_ID` in                      │
/// │  android/app/src/main/AndroidManifest.xml, and a                     │
/// │  `GADApplicationIdentifier` key in ios/Runner/Info.plist.            │
/// │  Both take the `ca-app-pub-XXXXXXXX~YYYYYYYY` form.                  │
/// └──────────────────────────────────────────────────────────────────────┘
abstract final class AdIds {
  /// Debug builds always serve Google's TEST units; release builds serve
  /// the live ones. Never ship a debug build against live units — tapping
  /// your own ads is an AdMob policy violation and can suspend the
  /// account. Set this to a constant only if you deliberately need to
  /// verify live fill on a device.
  static bool get useTestAds => kDebugMode;

  // ---- Live units ------------------------------------------------------
  static const _androidBanner = 'ca-app-pub-3208735875691916/8934478391';
  static const _androidInterstitial =
      'ca-app-pub-3208735875691916/5307214257';
  static const _androidRewarded = 'ca-app-pub-3208735875691916/2681050910';

  static const _iosBanner = 'ca-app-pub-3208735875691916/7325883253';
  static const _iosInterstitial = 'ca-app-pub-3208735875691916/1367969245';
  static const _iosRewarded = 'ca-app-pub-3208735875691916/2748449191';

  // ---- Google's official test units (safe, no revenue) ----------------
  static const _testAndroidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testAndroidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const _testIosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const _testIosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const _testIosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  /// Ads only exist on the mobile targets; everywhere else the ad layer is
  /// a no-op so desktop/web dev builds keep running.
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get _android => !kIsWeb && Platform.isAndroid;

  static String get banner => useTestAds
      ? (_android ? _testAndroidBanner : _testIosBanner)
      : (_android ? _androidBanner : _iosBanner);

  static String get interstitial => useTestAds
      ? (_android ? _testAndroidInterstitial : _testIosInterstitial)
      : (_android ? _androidInterstitial : _iosInterstitial);

  static String get rewarded => useTestAds
      ? (_android ? _testAndroidRewarded : _testIosRewarded)
      : (_android ? _androidRewarded : _iosRewarded);
}
