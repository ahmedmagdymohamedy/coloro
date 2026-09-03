import 'package:coloro/core/ads/ad_service.dart';
import 'package:coloro/screens/game/widgets/level_failed_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fail card is the game's largest exit — 46 of the first flight's players
/// reached it 291 times — so what it offers, and in what order, is worth
/// pinning down.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    VoidCallback? onWatchAd,
    VoidCallback? onSkip,
    bool skipCostsAnAd = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LevelFailedOverlay(
          onRetry: () {},
          onMenu: () {},
          onWatchAd: onWatchAd,
          onSkip: onSkip,
          skipCostsAnAd: skipCostsAnAd,
          slotsNow: 4,
          slotsMax: 8,
        ),
      ),
    );
    // The card stages itself in; run it out rather than settling, so the
    // pulsing buttons cannot spin the pump forever.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('offers no way past the level until the player is stuck', (
    tester,
  ) async {
    await pumpCard(tester, onWatchAd: () {});
    expect(find.text('KEEP GOING  ·  +1 SLOT'), findsOneWidget);
    expect(find.text('SKIP THIS PICTURE'), findsNothing);
  });

  testWidgets('offers the skip once it is handed one', (tester) async {
    await pumpCard(tester, onWatchAd: () {}, onSkip: () {});
    expect(find.text('SKIP THIS PICTURE'), findsOneWidget);
    // Both rewarded surfaces stand together: keep this board, or leave it.
    expect(find.text('KEEP GOING  ·  +1 SLOT'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
  });

  testWidgets('the wording tells the truth about whether an ad plays', (
    tester,
  ) async {
    await pumpCard(tester, onSkip: () {}, skipCostsAnAd: true);
    expect(
      find.text('Watch a short ad and move to the next picture'),
      findsOneWidget,
    );

    await pumpCard(tester, onSkip: () {});
    expect(find.text('Move on to the next picture'), findsOneWidget);
    expect(
      find.text('Watch a short ad and move to the next picture'),
      findsNothing,
      reason: 'no ad is available, so do not promise one',
    );
  });

  testWidgets('the skip fires', (tester) async {
    var skipped = false;
    await pumpCard(tester, onSkip: () => skipped = true);
    await tester.tap(find.text('SKIP THIS PICTURE'));
    expect(skipped, isTrue);
  });

  group('ad gate', () {
    // These two numbers decide what share of players ever generate revenue.
    // At 4 they excluded 92% of the first flight's installs.
    test('the banner runs from the first level', () {
      expect(AdService.adsFromLevel, 1);
    });

    test('the first finished level still ends without a full-screen ad', () {
      expect(AdService.interstitialFromLevel, 2);
    });
  });
}
