import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sfx.dart';

/// Fire-and-forget sound playback over a warm round-robin player pool, so
/// rapid sounds (pixel ticks) never cut each other off.
///
/// Every call is exception-safe: on platforms/tests without an audio plugin
/// the game keeps running silently.
class AudioController {
  AudioController._();

  static final AudioController instance = AudioController._();

  final Map<Sfx, List<AudioPlayer>> _pools = {};
  final Map<Sfx, int> _next = {};
  bool _initStarted = false;
  bool _ready = false;

  /// Master toggle, persisted by the settings/progress store.
  bool enabled = true;

  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      await AudioCache.instance.loadAll(
        [for (final s in Sfx.values) s.asset],
      );
      for (final sfx in Sfx.values) {
        final players = <AudioPlayer>[];
        for (var i = 0; i < sfx.pool; i++) {
          final p = AudioPlayer();
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource(sfx.asset));
          players.add(p);
        }
        _pools[sfx] = players;
        _next[sfx] = 0;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Audio unavailable: $e');
    }
  }

  final Map<AudioPlayer, double> _lastVolume = {};
  final Map<AudioPlayer, double> _lastRate = {};

  /// Plays [sfx]. [pitch] of 1.0 is natural; higher = faster/brighter.
  void play(Sfx sfx, {double pitch = 1.0, double volume = 1.0}) {
    if (!enabled || !_ready) return;
    final pool = _pools[sfx];
    if (pool == null || pool.isEmpty) return;
    final index = _next[sfx]! % pool.length;
    _next[sfx] = index + 1;
    final player = pool[index];
    unawaited(_playOn(player, pitch, volume));
  }

  Future<void> _playOn(AudioPlayer player, double pitch, double volume) async {
    try {
      await player.stop();
      // Skip redundant platform-channel calls: quantize and only send
      // volume/rate when they actually changed for this player.
      final v = (volume.clamp(0.0, 1.0) * 20).roundToDouble() / 20;
      final r = (pitch.clamp(0.5, 2.5) * 20).roundToDouble() / 20;
      if (_lastVolume[player] != v) {
        await player.setVolume(v);
        _lastVolume[player] = v;
      }
      if (_lastRate[player] != r) {
        await player.setPlaybackRate(r);
        _lastRate[player] = r;
      }
      await player.resume();
    } catch (_) {
      // Never let audio break gameplay.
    }
  }
}
