import 'package:coloro/core/ads/full_screen_ad_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in for an InterstitialAd/RewardedAd.
class _FakeAd {
  _FakeAd(this.id);
  final int id;
  bool disposed = false;
}

/// Builds a cache over a scripted loader so every failure mode the real
/// AdMob SDK produces can be reproduced deterministically.
class _Harness {
  _Harness({
    this.failures = 0,
    Duration ttl = const Duration(minutes: 50),
    int maxAttempts = 6,
  }) {
    cache = FullScreenAdCache<_FakeAd>(
      label: 'Test',
      ttl: ttl,
      maxAttempts: maxAttempts,
      // Tiny backoff so retry behaviour is testable in real time.
      backoff: const [Duration(milliseconds: 10)],
      loader: () async {
        loads++;
        if (loads <= failures) return null;
        return _FakeAd(loads);
      },
      disposer: (ad) => ad.disposed = true,
    );
  }

  late final FullScreenAdCache<_FakeAd> cache;
  int loads = 0;
  int failures;
}

/// Lets pending microtasks and short timers run.
Future<void> settle([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('warms one ad and reports ready', () async {
    final h = _Harness();
    h.cache.warm();
    await settle();

    expect(h.cache.isReady, isTrue);
    expect(h.loads, 1, reason: 'exactly one request for one ad');
  });

  test('overlapping warms do not produce duplicate requests', () async {
    final h = _Harness();
    h.cache
      ..warm()
      ..warm()
      ..warm();
    await settle();

    expect(h.loads, 1);
  });

  test('take() refills immediately, so the next show has inventory', () async {
    final h = _Harness();
    h.cache.warm();
    await settle();

    final first = h.cache.take();
    expect(first, isNotNull);
    // The replacement request must be in flight already — not deferred to
    // the ad's dismissal, which is what made the old code skip every other
    // opportunity.
    expect(h.cache.isLoading, isTrue);

    await settle();
    expect(h.cache.isReady, isTrue, reason: 'replacement is ready');
    expect(h.cache.take()!.id, isNot(first!.id));
  });

  test('shows repeatedly — the regression that broke after one ad', () async {
    final h = _Harness();
    h.cache.warm();
    await settle();

    for (var i = 0; i < 5; i++) {
      final ad = h.cache.take();
      expect(ad, isNotNull, reason: 'ad #${i + 1} should be available');
      await settle();
    }
    expect(h.loads, 6, reason: 'one initial load plus five refills');
  });

  test('retries after a failed load instead of giving up', () async {
    final h = _Harness(failures: 2);
    h.cache.warm();
    await settle(120);

    expect(h.loads, greaterThanOrEqualTo(3));
    expect(h.cache.isReady, isTrue, reason: 'recovered after two failures');
  });

  test('stops retrying at maxAttempts but revives on demand', () async {
    final h = _Harness(failures: 100, maxAttempts: 2);
    h.cache.warm();
    await settle(150);

    final afterGivingUp = h.loads;
    expect(afterGivingUp, lessThanOrEqualTo(4),
        reason: 'backoff must not turn into a request flood');

    await settle(120);
    expect(h.loads, afterGivingUp, reason: 'stays paused on its own');

    // A level start or app resume must always be able to revive it.
    h.failures = 0;
    h.cache.revive();
    await settle();
    expect(h.cache.isReady, isTrue);
  });

  test('discards an expired ad rather than showing a stale one', () async {
    final h = _Harness(ttl: Duration.zero);
    h.cache.warm();
    await settle();

    // Past its TTL the cached ad must not be handed out; AdMob would fail
    // the show. It is disposed and a fresh one requested.
    expect(h.cache.take(), isNull);
    await settle();
    expect(h.loads, greaterThanOrEqualTo(2));
  });

  test('dispose releases the held ad and stops further loading', () async {
    final h = _Harness();
    h.cache.warm();
    await settle();

    h.cache.dispose();
    final loadsAtDispose = h.loads;

    h.cache.warm();
    await settle();
    expect(h.loads, loadsAtDispose, reason: 'no loading after dispose');
    expect(h.cache.isReady, isFalse);
  });
}
