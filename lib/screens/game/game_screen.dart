import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/ads/ad_service.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/audio/audio_controller.dart';
import '../../core/audio/sfx.dart';
import '../../core/haptics/haptics.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/display_palette.dart';
import '../../data/bottle_factory.dart';
import '../../data/level_processor.dart';
import '../../data/progress_store.dart';
import '../../domain/models/level.dart';
import '../../domain/models/level_result.dart';
import '../../game/game_controller.dart';
import '../../game/game_events.dart';
import '../../game/vfx/vfx_controller.dart';
import '../../game/vfx/vfx_painter.dart';
import '../../game/widgets/bead_atlas.dart';
import '../../game/widgets/game_hud.dart';
import '../../game/widgets/machine_frame.dart';
import '../../game/widgets/pixel_canvas.dart';
import '../../game/widgets/slot_bar.dart';
import '../../game/widgets/tray_view.dart';
import '../../shared/widgets/game_toast.dart';
import 'widgets/level_complete_overlay.dart';
import 'widgets/level_failed_overlay.dart';
import 'widgets/notify_permission_sheet.dart';

/// The player is asked to enable reminders once, after finishing this level.
const _askForNotificationsAfterLevel = 3;

/// Consecutive losses on one level before the player is offered a way past it.
///
/// The first flight of paid installs showed 46 players losing 291 times — 6.3
/// losses each — while only 24 of 99 ever won a level at all. Those attempts
/// were the game's clearest signal of intent and its largest exit. Three is
/// deliberately past "unlucky" and short of "gave up".
const _skipOfferAfterLosses = 3;

/// One level of gameplay: loads the pixel grid, then wires the simulation,
/// audio, haptics and VFX together around a single frame ticker.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    required this.hasNextLevel,
  });

  final Level level;
  final bool hasNextLevel;

  @override
  State<GameScreen> createState() => GameScreenState();
}

/// Public so integration/render tests can drive a smart bot against the
/// live [GameController] (see [debugGame]).
class GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  GameController? _game;
  BeadAtlas? _atlas;
  final _vfx = VfxController();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Per-frame pulse for always-moving visuals (track chevrons, slot
  /// wobbles, shake). Cheap listeners only.
  final _frame = FrameNotifier();

  /// Fires only while beads are landing/popping — the board stays a cached
  /// layer whenever the machine is idle.
  final _canvasTick = FrameNotifier();

  /// Fires only while particles/flights/shake exist.
  final _vfxTick = FrameNotifier();

  final _sweep = ValueNotifier<double>(-1);

  double _canvasActiveUntil = 0.5; // paint the first frames
  bool _canvasWasActive = true;
  bool _vfxWasActive = false;

  final _stackKey = GlobalKey();
  final _canvasKey = GlobalKey();
  // One key per slot the machine can ever have: 4 base slots plus every slot
  // a rewarded rescue can add, up to GameController.maxSlots.
  final _slotKeys = List.generate(GameController.maxSlots, (_) => GlobalKey());
  final _columnKeys = List.generate(4, (_) => GlobalKey());

  double _lastTickSoundAt = -1;

  /// Hold-to-fast-forward: while a pointer is held on NON-interactive
  /// space (not the tray, slots or HUD) the simulation runs at 2×.
  final Set<int> _boostPointers = {};
  bool get _boosting => _boostPointers.isNotEmpty;

  final _hudRegionKey = GlobalKey();
  final _slotRegionKey = GlobalKey();
  final _trayRegionKey = GlobalKey();

  /// True when [globalPos] lands on the bottle tray. Holding anywhere else
  /// — the picture, the slots, the margins — fast-forwards; only picking
  /// bottles is exempt.
  bool _isInteractiveArea(Offset globalPos) {
    final box = _trayRegionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(globalPos);
  }

  LevelResult? _result;
  bool _machineJammed = false;
  bool _loadFailed = false;

  /// Consecutive losses on this level, including the one on screen. Read from
  /// [ProgressStore] rather than held here because every retry builds a fresh
  /// GameScreen — and because a player who closes the app in frustration
  /// should still be offered the way out when they come back.
  int _lossStreak = 0;

  /// Test hook: the live simulation (null while loading).
  @visibleForTesting
  GameController? get debugGame => _game;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    _vfx.onPixelArrived = (pixel) {
      // Collect mode: the bead lands IN the bottle — sparkle + tick there.
      final game = _game;
      if (game == null) return;
      _vfx.sparkle(pixel.to, pixel.color);
      _playTickSound(game);
    };
    _vfx.onBottleArrived = (bottle) {
      _game?.slotArrived(bottle.slotIndex);
      _vfx.shake(2.0);
      AudioController.instance.play(Sfx.tap, pitch: 0.9, volume: 0.7);
    };
    _load();
  }

  Future<void> _load() async {
    try {
      final grid = await LevelProcessor.process(widget.level);
      if (grid.isEmpty) throw StateError('Level image has no paintable pixels');
      final atlas = await BeadAtlas.build(grid.palette);
      if (!mounted) return;
      final game = GameController(
        grid: grid,
        bottles: BottleFactory.build(
          grid,
          seed: widget.level.number,
          shuffleWindow: widget.level.shuffleWindow,
          dealSeed: widget.level.dealSeed,
        ),
        seed: widget.level.number,
      );
      game.onEvent = _onGameEvent;
      setState(() {
        _game = game;
        _atlas = atlas;
      });
      _ticker.start();
      AnalyticsService.instance.gameStarted(
        level: widget.level.number,
        hard: widget.level.hard,
      );
      // Warm both full-screen ads now: the rescue offer must be instant if
      // they lose, and the interstitial must already be in hand by the time
      // they finish — otherwise it slips to the following level.
      AdService.instance.prewarm();
    } catch (e) {
      debugPrint('Level load failed: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _atlas?.dispose();
    _game?.dispose();
    _frame.dispose();
    _canvasTick.dispose();
    _vfxTick.dispose();
    _sweep.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Frame loop
  // ---------------------------------------------------------------------------

  void _onFrame(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _lastTick).inMicroseconds / 1e6);
    _lastTick = elapsed;
    final game = _game;
    if (game == null) return;

    // Hold anywhere → 3× speed (simulation and effects together). Raised
    // from 2× alongside the faster base fill rate: the point of the hold is
    // to skip ahead when the line you picked is obviously working.
    final mult = _boosting && game.phase == GamePhase.playing ? 3.0 : 1.0;
    game.tick(dt * mult);
    _vfx.update(dt * mult);
    _frame.notify();

    // Gate the heavy layers: paint only while they're actually animating
    // (plus one trailing frame so they settle into their final state).
    final canvasActive = game.time <= _canvasActiveUntil || _sweep.value >= 0;
    if (canvasActive || _canvasWasActive) _canvasTick.notify();
    _canvasWasActive = canvasActive;

    final vfxActive = _vfx.hasWork || _vfx.shakeOffset != Offset.zero;
    if (vfxActive || _vfxWasActive) _vfxTick.notify();
    _vfxWasActive = vfxActive;
  }

  /// Pixel-collect tick. Rate-limited so a fast machine stays pleasant
  /// rather than becoming a buzzsaw.
  ///
  /// The pitch deliberately does NOT track progress any more. It used to
  /// climb from 0.9 to 1.35 as the picture emptied, and playtesting was
  /// blunt about it: the sound just kept speeding up and got grating over a
  /// long level. It now sits at a fixed pitch with a tiny deterministic
  /// wobble — enough that consecutive ticks aren't machine-identical,
  /// without ever trending anywhere.
  void _playTickSound(GameController game) {
    if (game.time - _lastTickSoundAt < _tickMinGap) return;
    _lastTickSoundAt = game.time;
    final wobble = math.sin(game.time * 11.7) * 0.05;
    AudioController.instance.play(Sfx.tick, pitch: 1.0 + wobble, volume: 0.45);
    _pulseHaptic(game);
  }

  /// Shortest gap between two pixel ticks. Raised with the faster fill rate
  /// so the audio density stayed where it was when the machine sped up.
  static const _tickMinGap = 0.055;

  /// Continuous haptic texture while the machine drinks — the single most
  /// asked-for piece of feedback ("more haptics"). Runs at roughly half the
  /// tick rate so it reads as a purr rather than a rattle, and never fires
  /// once the level is over.
  static const _hapticMinGap = 0.11;
  double _lastHapticAt = -1;

  void _pulseHaptic(GameController game) {
    if (game.phase != GamePhase.playing) return;
    if (game.time - _lastHapticAt < _hapticMinGap) return;
    _lastHapticAt = game.time;
    Haptics.tick();
  }

  /// Progress milestones get a heavier, distinct bump — a small "you are
  /// getting somewhere" beat at each quarter of the picture.
  static const _milestones = [0.25, 0.5, 0.75];
  int _milestonesHit = 0;

  void _checkMilestone(GameController game) {
    if (_milestonesHit >= _milestones.length) return;
    if (game.progress < _milestones[_milestonesHit]) return;
    _milestonesHit++;
    Haptics.medium();
    AudioController.instance.play(Sfx.pop, pitch: 1.15, volume: 0.5);
  }

  // ---------------------------------------------------------------------------
  // Game events → juice
  // ---------------------------------------------------------------------------

  void _onGameEvent(GameEvent event) {
    switch (event) {
      case BottleLaunched(:final bottle, :final column, :final slotIndex):
        final from = _centerOf(_columnKeys[column]);
        final to = _centerOf(_slotKeys[slotIndex]);
        if (from != null && to != null) {
          _vfx.launchBottle(
            bottle: bottle,
            color: DisplayPalette.of(_game!.grid.palette[bottle.colorIndex]),
            from: from,
            to: to,
            slotIndex: slotIndex,
            size: const Size(40, 52),
          );
        } else {
          // Could not resolve geometry; dock instantly.
          _game!.slotArrived(slotIndex);
        }
        AudioController.instance.play(Sfx.whoosh, volume: 0.45, pitch: 1.1);
        Haptics.light();

      case LaunchRefused():
        AudioController.instance.play(Sfx.error);
        Haptics.medium();

      case CellFillStarted(
        :final cellIndex,
        :final colorIndex,
        :final slotIndex,
      ):
        final game = _game!;
        // The cell is plucked immediately (it dims with a shrink animation)
        // and the bead falls into the docked bottle below.
        game.cellArrived(cellIndex);
        _checkMilestone(game);
        _canvasActiveUntil = game.time + 0.5;

        final canvasBox =
            _canvasKey.currentContext?.findRenderObject() as RenderBox?;
        final stackBox =
            _stackKey.currentContext?.findRenderObject() as RenderBox?;
        final to = _centerOf(_slotKeys[slotIndex]);
        if (to == null || canvasBox == null || stackBox == null) return;
        final local = PixelCanvas.cellCenter(
          canvasBox.size,
          game.grid,
          cellIndex,
        );
        final from = stackBox.globalToLocal(canvasBox.localToGlobal(local));
        // Gentle sideways arc on the way down.
        final mid = Offset.lerp(from, to, 0.5)!;
        final control = mid.translate((from.dx - to.dx) * 0.25, 12);
        _vfx.launchPixel(
          from: from,
          to: to,
          control: control,
          color: DisplayPalette.of(game.grid.palette[colorIndex]),
          cellIndex: cellIndex,
          size: math.max(
            6,
            PixelCanvas.cellSize(canvasBox.size, game.grid) * 0.8,
          ),
          follow: () => _liveBottlePoint(slotIndex),
        );

      case BottleEmptied(:final slotIndex, :final colorIndex):
        final at = _centerOf(_slotKeys[slotIndex]);
        if (at != null) {
          final color = DisplayPalette.of(_game!.grid.palette[colorIndex]);
          _vfx.burst(at, color);
          _vfx.ring(at, color);
        }
        _vfx.shake(3.5);
        AudioController.instance.play(Sfx.bottlePop);
        Haptics.medium();

      case SlotStuckChanged(:final stuck):
        if (stuck) {
          // Soft warning clunk — the bottle's color isn't on the edge.
          AudioController.instance.play(Sfx.error, pitch: 1.4, volume: 0.45);
          // Promoted from light: a bottle going hungry is the warning the
          // whole fail state builds from, so it should be felt, not guessed.
          Haptics.medium();
          _vfx.shake(1.5);
        }

      case LevelFailed():
        _onLevelFailed();

      case LevelCompleted(:final result):
        _onLevelComplete(result);
    }
  }

  Future<void> _onLevelFailed() async {
    AnalyticsService.instance.gameLost(
      level: widget.level.number,
      progress: _game?.progress ?? 0,
    );
    Haptics.heavy();
    _vfx.shake(7);
    AudioController.instance.play(Sfx.error, pitch: 0.75);

    final store = await ProgressStore.load();
    final streak = await store.recordLoss(widget.level.number);

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _lossStreak = streak;
      _machineJammed = true;
    });

    // The rescue and skip offers are only wired when an ad is in hand, and
    // both are evaluated at build time. If inventory arrives a moment late
    // the offer would silently never appear, so ask once more shortly after.
    if (!AdService.instance.isRewardedReady) {
      AdService.instance.prewarm();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted && _machineJammed) setState(() {});
    }
  }

  Future<void> _onLevelComplete(LevelResult result) async {
    Haptics.heavy();
    AudioController.instance.play(Sfx.sweep);
    // Run the shine sweep, then celebrate.
    _sweep.value = 0;
    final sweepTicker = Stopwatch()..start();
    void step() {
      if (!mounted) return;
      final t = sweepTicker.elapsedMilliseconds / 700;
      _sweep.value = t.clamp(0.0, 1.0);
      if (t < 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) => step());
      }
    }

    step();
    // Clear the sweep once it has passed so the board can go back to sleep.
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _sweep.value = -1;
    });

    AnalyticsService.instance.gameWon(
      level: widget.level.number,
      seconds: result.elapsedSeconds,
    );
    final store = await ProgressStore.load();
    await store.recordCompletion(widget.level.number);
    // Finishing level 3 unlocks the banner for the rest of the session.
    AdService.instance.updateGate(store.unlockedLevel);

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null) {
      final bounds = Offset.zero & stackBox.size;
      _vfx.confetti(bounds, AppColors.festive, count: 110);
      final rnd = math.Random();
      for (var i = 0; i < 4; i++) {
        _vfx.firework(
          Offset(
            bounds.width * (0.2 + rnd.nextDouble() * 0.6),
            bounds.height * (0.15 + rnd.nextDouble() * 0.3),
          ),
          AppColors.festive[rnd.nextInt(AppColors.festive.length)],
        );
      }
    }
    AudioController.instance.play(Sfx.win);
    setState(() => _result = result);

    await _maybeAskForNotifications(store);
  }

  /// Asked once, immediately after level 3 — the first moment the player has
  /// demonstrably enjoyed the game. Asking on first launch converts far worse
  /// and burns the one OS prompt we get.
  Future<void> _maybeAskForNotifications(ProgressStore store) async {
    if (widget.level.number != _askForNotificationsAfterLevel) return;
    if (store.notifyAsked) return;
    if (!NotificationService.instance.supported) return;
    if (await NotificationService.instance.hasPermission()) return;

    // Let the celebration land before interrupting it.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    await store.markNotifyAsked();
    if (!mounted) return;
    final wantsThem = await NotifyPermissionSheet.show(context);
    AnalyticsService.instance.notifyPromptAnswered(accepted: wantsThem);
    if (!wantsThem) return;

    final granted = await NotificationService.instance.requestPermission();
    AnalyticsService.instance.notifyPermission(granted: granted);
  }

  Offset? _centerOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stackBox == null) return null;
    return stackBox.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

  /// Between-levels interstitial (from level 3 on), then move along. The
  /// ad is skipped silently whenever one is not ready.
  Future<void> _goToNextLevel() async {
    await _showExitInterstitial('interstitial');
    if (!mounted) return;
    Navigator.of(context).pop(GameExit.playNext);
  }

  /// Retry after a machine jam.
  ///
  /// Losing and retrying is the single most travelled transition in the
  /// game, and it was the only exit from a level that never showed an ad —
  /// reported as a bug, and it is also the biggest single piece of unserved
  /// inventory in the app. It runs through exactly the same gate as the
  /// between-levels ad (level >= 4, at least 30s since the last one), so
  /// onboarding stays clean and a retry streak can't turn into a wall of
  /// full-screen ads.
  Future<void> _retryLevel() async {
    await _showExitInterstitial('interstitial_retry');
    if (!mounted) return;
    Navigator.of(context).pop(GameExit.replay);
  }

  /// Leaving to the menu from a finished board.
  ///
  /// This goes through the same gate as every other exit, because it used
  /// to be the one that didn't — and players found it: lose, tap Home to
  /// dodge the ad, then start the next attempt from the menu. Closing it
  /// also makes the ad honest. It isn't a tax on retrying specifically; it
  /// is simply what happens when you leave a level, whichever door you use.
  Future<void> _exitToMenu() async {
    await _showExitInterstitial('interstitial_menu');
    if (!mounted) return;
    Navigator.of(context).pop(GameExit.toMenu);
  }

  Future<void> _showExitInterstitial(String format) async {
    if (!AdService.instance.supported) return;
    final shown = await AdService.instance.maybeShowInterstitial(
      level: widget.level.number,
    );
    if (shown) {
      AnalyticsService.instance.adShown(
        format: format,
        level: widget.level.number,
      );
    }
  }

  /// Rewarded-ad rescue after a jam: watch an ad, get a 5th slot, and carry
  /// on from exactly where the machine stopped.
  Future<void> _watchAdForExtraSlot() async {
    final earned = await AdService.instance.showRewarded();
    if (!mounted) return;
    if (!earned) return;
    AnalyticsService.instance
      ..adShown(format: 'rewarded', level: widget.level.number)
      ..extraSlotEarned(level: widget.level.number);
    _game?.grantExtraSlotAndResume();
    setState(() => _machineJammed = false);
    Haptics.medium();
  }

  /// The way out of a level the player cannot solve.
  ///
  /// Offered only after [_skipOfferAfterLosses] losses on the same board. It
  /// shows a rewarded ad when one is in hand, but the skip is granted either
  /// way: a player stuck three times who is then also told "no" churns, and a
  /// churned player earns nothing at all. The level is recorded as skipped
  /// rather than completed, so the menu keeps telling the truth and the
  /// player can come back and beat it properly.
  Future<void> _skipLevel() async {
    if (AdService.instance.isRewardedReady) {
      final earned = await AdService.instance.showRewarded();
      if (!mounted) return;
      if (earned) {
        AnalyticsService.instance.adShown(
          format: 'rewarded_skip',
          level: widget.level.number,
        );
      }
    }
    final store = await ProgressStore.load();
    await store.skipLevel(widget.level.number);
    AnalyticsService.instance.levelSkipped(
      level: widget.level.number,
      losses: _lossStreak,
    );
    AdService.instance.updateGate(store.unlockedLevel);
    if (!mounted) return;
    Haptics.medium();
    // Same door as a win: the menu advances to the next picture.
    Navigator.of(context).pop(GameExit.playNext);
  }

  /// The docked bottle's on-screen position, or null once it popped
  /// (callers keep their last known point).
  Offset? _liveBottlePoint(int slotIndex) {
    final game = _game;
    if (game == null || game.slots[slotIndex] == null) return null;
    return _centerOf(_slotKeys[slotIndex]);
  }

  void _onTapColumn(int column) {
    _game?.launchFromColumn(column);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  /// A single stray back press used to drop the player straight back to the
  /// menu, throwing away an in-progress board. Leaving now must be asked for
  /// twice, inside this window.
  static const _backConfirmWindow = Duration(seconds: 2);
  DateTime? _lastBackAt;

  /// Only guard a board that still has something to lose. Once the level is
  /// finished the progress is already saved, and a load failure has nothing
  /// to protect, so back behaves normally in both cases.
  bool get _needsExitConfirm => !_loadFailed && _result == null;

  void _onBackPressed() {
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last != null && now.difference(last) <= _backConfirmWindow) {
      GameToast.dismiss();
      Navigator.of(context).pop(GameExit.toMenu);
      return;
    }
    _lastBackAt = now;
    Haptics.light();
    GameToast.show(context, 'Press back again to leave this level');
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return PopScope<GameExit>(
      canPop: !_needsExitConfirm,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPressed();
      },
      child: _buildBody(game),
    );
  }

  Widget _buildBody(GameController? game) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bgBottom],
          ),
        ),
        child: SafeArea(
          bottom: false,
          // Keep a phone-shaped play area even in wide desktop windows.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: _loadFailed
                  ? _LoadError(onBack: () => Navigator.of(context).pop())
                  : game == null || _atlas == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.candyPink,
                      ),
                    )
                  : _buildGame(game),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGame(GameController game) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (!_isInteractiveArea(e.position)) {
          setState(() => _boostPointers.add(e.pointer));
        }
      },
      onPointerUp: (e) {
        if (_boostPointers.remove(e.pointer)) setState(() {});
      },
      onPointerCancel: (e) {
        if (_boostPointers.remove(e.pointer)) setState(() {});
      },
      child: Stack(
        key: _stackKey,
        children: [
          Column(
            children: [
              RepaintBoundary(
                key: _hudRegionKey,
                child: GameHud(
                  level: widget.level,
                  progress: game.progress01,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _frame,
                  builder: (context, child) => Transform.translate(
                    offset: _vfx.shakeOffset,
                    child: child,
                  ),
                  // Boundary directly under the shake transform: moving the
                  // machine only re-composites this layer, never repaints it.
                  child: RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                      // Full-square pictures → keep the whole machine square so
                      // the production line hugs the image on all sides.
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: MachineFrame(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: KeyedSubtree(
                                key: _canvasKey,
                                child: PixelCanvas(
                                  controller: game,
                                  atlas: _atlas!,
                                  repaint: _canvasTick,
                                  sweepProgress: _sweep,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              RepaintBoundary(
                key: _slotRegionKey,
                child: SlotBar(
                  controller: game,
                  slotKeys: _slotKeys,
                  repaint: _frame,
                ),
              ),
              const SizedBox(height: 8),
              RepaintBoundary(
                key: _trayRegionKey,
                child: TrayView(
                  controller: game,
                  columnKeys: _columnKeys,
                  onTapColumn: _onTapColumn,
                ),
              ),
            ],
          ),
          // All transient effects, isolated in their own layer and painted
          // only while something is actually flying/bursting.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: VfxPainter(vfx: _vfx, repaint: _vfxTick),
                ),
              ),
            ),
          ),
          if (_machineJammed)
            Positioned.fill(
              child: LevelFailedOverlay(
                onRetry: _retryLevel,
                onMenu: _exitToMenu,
                // Repeatable: every jam can be bought off with another slot
                // until the machine reaches its ceiling, after which the
                // level has to be replayed.
                onWatchAd:
                    AdService.instance.isRewardedReady && game.canEarnExtraSlot
                    ? _watchAdForExtraSlot
                    : null,
                // Stuck for the third time on this board — offer the door out
                // rather than a fourth identical defeat.
                onSkip: _lossStreak >= _skipOfferAfterLosses && widget.hasNextLevel
                    ? _skipLevel
                    : null,
                skipCostsAnAd: AdService.instance.isRewardedReady,
                slotsNow: game.activeSlotCount,
                slotsMax: GameController.maxSlots,
              ),
            ),
          if (_result != null)
            Positioned.fill(
              child: LevelCompleteOverlay(
                level: widget.level,
                grid: game.grid,
                hasNextLevel: widget.hasNextLevel,
                onNext: _goToNextLevel,
                onReplay: _retryLevel,
                onMenu: _exitToMenu,
              ),
            ),
          // Fast-forward badge while the player holds the screen.
          Positioned(
            top: 64,
            right: 18,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _boosting && game.phase == GamePhase.playing ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.candyYellow.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55000000), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fast_forward_rounded,
                        size: 18,
                        color: Color(0xFF4A3808),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'x3',
                        style: AppTypography.style(
                          size: 15,
                          weight: 700,
                          color: const Color(0xFF4A3808),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the player left the game screen.
enum GameExit { toMenu, playNext, replay }

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            size: 56,
            color: AppColors.textDim,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load this level',
            style: TextStyle(color: AppColors.textSoft, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    );
  }
}

/// Per-frame repaint pulse for painters and animated builders.
class FrameNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
