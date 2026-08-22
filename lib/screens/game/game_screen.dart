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
      AnalyticsService.instance
          .gameStarted(level: widget.level.number, hard: widget.level.hard);
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

    // Hold anywhere → 2× speed (simulation and effects together).
    final mult = _boosting && game.phase == GamePhase.playing ? 2.0 : 1.0;
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

  void _playTickSound(GameController game) {
    // Rate-limit the pixel tick so bursts stay pleasant, pitch up with combo.
    if (game.time - _lastTickSoundAt < 0.045) return;
    _lastTickSoundAt = game.time;
    // Rises gently as the picture empties — a sense of momentum without
    // any combo bookkeeping.
    final pitch = 0.9 + game.progress * 0.45;
    AudioController.instance.play(Sfx.tick, pitch: pitch, volume: 0.5);
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
            color: Color(_game!.grid.palette[bottle.colorIndex]),
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

      case CellFillStarted(:final cellIndex, :final colorIndex, :final slotIndex):
        final game = _game!;
        // The cell is plucked immediately (it dims with a shrink animation)
        // and the bead falls into the docked bottle below.
        game.cellArrived(cellIndex);
        _canvasActiveUntil = game.time + 0.5;

        final canvasBox =
            _canvasKey.currentContext?.findRenderObject() as RenderBox?;
        final stackBox =
            _stackKey.currentContext?.findRenderObject() as RenderBox?;
        final to = _centerOf(_slotKeys[slotIndex]);
        if (to == null || canvasBox == null || stackBox == null) return;
        final local =
            PixelCanvas.cellCenter(canvasBox.size, game.grid, cellIndex);
        final from = stackBox.globalToLocal(canvasBox.localToGlobal(local));
        // Gentle sideways arc on the way down.
        final mid = Offset.lerp(from, to, 0.5)!;
        final control = mid.translate((from.dx - to.dx) * 0.25, 12);
        _vfx.launchPixel(
          from: from,
          to: to,
          control: control,
          color: Color(game.grid.palette[colorIndex]),
          cellIndex: cellIndex,
          size: math.max(
              6, PixelCanvas.cellSize(canvasBox.size, game.grid) * 0.8),
          follow: () => _liveBottlePoint(slotIndex),
        );

      case BottleEmptied(:final slotIndex, :final colorIndex):
        final at = _centerOf(_slotKeys[slotIndex]);
        if (at != null) {
          final color = Color(_game!.grid.palette[colorIndex]);
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
          Haptics.light();
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
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _machineJammed = true);
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
    if (AdService.instance.supported) {
      final shown = await AdService.instance
          .maybeShowInterstitial(completedLevel: widget.level.number);
      if (shown) {
        AnalyticsService.instance.adShown(
          format: 'interstitial',
          level: widget.level.number,
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(GameExit.playNext);
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
                onRetry: () => Navigator.of(context).pop(GameExit.replay),
                onMenu: () => Navigator.of(context).pop(GameExit.toMenu),
                // Repeatable: every jam can be bought off with another slot
                // until the machine reaches its ceiling, after which the
                // level has to be replayed.
                onWatchAd:
                    AdService.instance.isRewardedReady && game.canEarnExtraSlot
                        ? _watchAdForExtraSlot
                        : null,
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
                onReplay: () => Navigator.of(context).pop(GameExit.replay),
                onMenu: () => Navigator.of(context).pop(GameExit.toMenu),
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
                        'x2',
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
