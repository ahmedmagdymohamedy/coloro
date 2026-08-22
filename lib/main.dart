import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/coloro_app.dart';
import 'core/ads/ad_service.dart';
import 'core/analytics/analytics_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only arcade experience on phones.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // Firebase and AdMob are best-effort: a failure here (an unconfigured
  // platform, no network, a dev desktop build) must never stop the game
  // from starting.
  await _initFirebase();
  unawaited(AdService.instance.init().catchError(
      (Object e) => debugPrint('AdMob init failed: \$e')));

  runApp(const ColoroApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    AnalyticsService.instance.enable(analytics);
    debugPrint('Firebase ready — analytics enabled.');
  } catch (e) {
    debugPrint('Firebase unavailable ($e) — running without analytics.');
  }
}

void unawaited(Future<void> future) {
  future.catchError((Object e) => debugPrint('background init failed: $e'));
}
