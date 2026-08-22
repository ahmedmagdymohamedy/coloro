import 'package:coloro/domain/models/level.dart';
import 'package:coloro/screens/game/game_screen.dart';
import 'package:coloro/shared/widgets/game_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the real GameScreen's back handling through a Navigator, so the
/// system back button travels the same PopScope path a device uses.
///
/// The level never finishes processing here and that is deliberate: an
/// in-progress board is exactly the state the confirmation protects, and it
/// keeps the test free of image decoding. Every wait is an explicit pump —
/// the game runs a Ticker that never idles, so pumpAndSettle would spin until
/// it timed out.
void main() {
  const level = Level(
    number: 1,
    assetPath: 'assets/levels/1.png',
    gridSize: 16,
    maxColors: 5,
  );

  setUp(() => SharedPreferences.setMockInitialValues({'unlocked_level': 9}));
  tearDown(GameToast.dismiss);

  Future<void> frames(WidgetTester tester, [int count = 10]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> pumpGame(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('menu'))),
    );
    final context = tester.element(find.text('menu'));
    Navigator.of(context).push(
      MaterialPageRoute<GameExit>(
        builder: (_) => const GameScreen(level: level, hasNextLevel: true),
      ),
    );
    await frames(tester, 20);
    expect(find.byType(GameScreen), findsOneWidget);
  }

  /// Fires the platform back button the way Android does.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await frames(tester, 6);
  }

  testWidgets('one back press keeps the level and shows a hint',
      (tester) async {
    await pumpGame(tester);

    await pressBack(tester);

    expect(find.byType(GameScreen), findsOneWidget,
        reason: 'a single back must not discard the board');
    expect(find.text('Press back again to leave this level'), findsOneWidget);
  });

  testWidgets('a second back press inside the window leaves', (tester) async {
    await pumpGame(tester);

    await pressBack(tester);
    await pressBack(tester);
    await frames(tester, 20);

    expect(find.byType(GameScreen), findsNothing,
        reason: 'a confirmed exit returns to the menu');
    expect(find.text('menu'), findsOneWidget);
  });

  testWidgets('the confirmation expires, so a later back press only warns',
      (tester) async {
    await pumpGame(tester);

    await pressBack(tester);
    // Well past the 2s window: this must start a fresh confirmation rather
    // than completing the earlier one.
    await tester.pump(const Duration(seconds: 4));
    await pressBack(tester);

    expect(find.byType(GameScreen), findsOneWidget,
        reason: 'an expired confirmation must not count as the second press');
  });
}
