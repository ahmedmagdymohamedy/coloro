import 'package:flutter/material.dart';

import '../core/ads/banner_ad_slot.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../screens/menu/main_menu_screen.dart';

class ColoroApp extends StatelessWidget {
  const ColoroApp({super.key});

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
