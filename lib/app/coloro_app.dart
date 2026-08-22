import 'package:flutter/material.dart';

import '../core/ads/ad_service.dart';
import '../core/ads/banner_ad_slot.dart';
import '../core/notifications/notification_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../screens/menu/main_menu_screen.dart';

class ColoroApp extends StatefulWidget {
  const ColoroApp({super.key});

  @override
  State<ColoroApp> createState() => _ColoroAppState();
}

class _ColoroAppState extends State<ColoroApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Every return to — and every exit from — the game pushes both reminders
  /// back out. An active player therefore never receives one; only a real
  /// absence lets a timer run all the way down.
  ///
  /// `paused` matters as much as `resumed`: re-arming only on open would
  /// start the 24h clock when the session began, so someone who played for
  /// three hours would be nudged 21h after they actually put the game down.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      NotificationService.instance.rescheduleReminders();
    }
    if (state == AppLifecycleState.resumed) {
      // Coming back from the background is the most likely moment for a
      // connectivity problem to have resolved, so give ad loading a clean
      // slate rather than leaving it in a backed-off state.
      AdService.instance.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coloro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgBottom,
        fontFamily: AppTypography.family,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.candyPink,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainMenuScreen(),
      // The banner lives above every screen's bottom edge, so it is
      // present on the menu and during play without any screen knowing
      // about ads. It renders nothing until an ad actually loads (and
      // never on desktop/web).
      builder: (context, child) => Column(
        children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          const SafeArea(top: false, child: BannerAdSlot()),
        ],
      ),
    );
  }
}
