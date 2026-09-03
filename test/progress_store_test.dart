import 'package:coloro/data/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the "player is stuck" bookkeeping added for the skip offer.
///
/// The distinction these tests protect is that a skipped level is *unlocked
/// but not finished*: the campaign has to let the player past without ever
/// claiming they solved it, otherwise the menu's check marks and
/// [ProgressStore.completedCount] quietly become lies.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProgressStore> freshStore([Map<String, Object> seed = const {}]) async {
    SharedPreferences.setMockInitialValues(seed);
    ProgressStore.resetForTest();
    return ProgressStore.load();
  }

  group('loss streak', () {
    test('counts consecutive losses on the same level', () async {
      final store = await freshStore();
      expect(store.lossStreak(1), 0);
      expect(await store.recordLoss(1), 1);
      expect(await store.recordLoss(1), 2);
      expect(store.lossStreak(1), 2);
    });

    test('moving to another level starts a new run', () async {
      final store = await freshStore();
      await store.recordLoss(1);
      await store.recordLoss(1);
      expect(store.lossStreak(2), 0, reason: 'a different board is not stuck');
      expect(await store.recordLoss(2), 1);
      expect(store.lossStreak(1), 0, reason: 'the old run is gone');
    });

    test('winning clears the run', () async {
      final store = await freshStore();
      await store.recordLoss(1);
      await store.recordLoss(1);
      await store.recordCompletion(1);
      expect(store.lossStreak(1), 0);
    });
  });

  group('skipping', () {
    test('unlocks the next level without crediting a completion', () async {
      final store = await freshStore();
      await store.skipLevel(1);

      expect(store.unlockedLevel, 2, reason: 'the player may move on');
      expect(store.isSkipped(1), isTrue);
      expect(store.isCompleted(1), isFalse, reason: 'they did not solve it');
      expect(store.completedCount, 0);
    });

    test('clears the loss run that earned it', () async {
      final store = await freshStore();
      await store.recordLoss(3);
      await store.recordLoss(3);
      await store.recordLoss(3);
      await store.skipLevel(3);
      expect(store.lossStreak(3), 0);
    });

    test('never pulls progress backwards', () async {
      final store = await freshStore({'unlocked_level': 9});
      await store.skipLevel(2);
      expect(store.unlockedLevel, 9);
      expect(store.isCompleted(2), isFalse);
      expect(
        store.completedCount,
        7,
        reason: '8 unlocked levels behind level 9, one of them only skipped',
      );
    });

    test('coming back and solving it promotes the skip to a completion',
        () async {
      final store = await freshStore();
      await store.skipLevel(1);
      expect(store.isCompleted(1), isFalse);

      await store.recordCompletion(1);
      expect(store.isSkipped(1), isFalse);
      expect(store.isCompleted(1), isTrue);
      expect(store.completedCount, 1);
    });

    test('survives a reload, because a stuck player closes the app', () async {
      final store = await freshStore();
      await store.recordLoss(4);
      await store.recordLoss(4);
      await store.skipLevel(4);

      ProgressStore.resetForTest();
      final reloaded = await ProgressStore.load();
      expect(reloaded.isSkipped(4), isTrue);
      expect(reloaded.unlockedLevel, 5);
    });
  });
}
