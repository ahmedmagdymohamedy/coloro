import 'package:flutter/material.dart';

import '../../app/transitions.dart';
import '../../core/audio/audio_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/level_catalog.dart';
import '../../data/progress_store.dart';
import '../../domain/models/level.dart';
import '../../shared/widgets/bouncy_button.dart';
import '../game/game_screen.dart';
import 'widgets/game_title.dart';
import 'widgets/level_preview_card.dart';
import 'widgets/menu_background.dart';

/// Landing screen: animated backdrop, bouncy title, next-level preview and
/// a big PLAY call-to-action.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _time;
  LevelCatalog? _catalog;
  ProgressStore? _store;

  /// Level carousel: swipe back to any past level and replay it.
  PageController? _pageController;
  int _selectedPage = 0;

  @override
  void initState() {
    super.initState();
    // Unbounded clock whose value == seconds on screen, shared by all idle
    // animations. (A huge target would make sin() jitter randomly.)
    _time = AnimationController.unbounded(vsync: this)
      ..animateTo(
        86400,
        duration: const Duration(days: 1),
        curve: Curves.linear,
      );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    AudioController.instance.init().then((_) {
      if (_store != null) {
        AudioController.instance.enabled = _store!.soundEnabled;
      }
    });
    final catalog = await LevelCatalog.load();
    final store = await ProgressStore.load();
    AudioController.instance.enabled = store.soundEnabled;
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _store = store;
      _selectedPage = store.unlockedLevel.clamp(1, catalog.levels.length) - 1;
    });
  }

  /// The controller is (re)built by the carousel's LayoutBuilder so the
  /// card keeps a fixed ~250px width whatever the screen width is.
  PageController _controllerFor(double screenWidth) {
    final fraction = (250 / screenWidth).clamp(0.16, 0.68);
    final current = _pageController;
    if (current != null && (current.viewportFraction - fraction).abs() < 0.02) {
      return current;
    }
    current?.dispose();
    return _pageController = PageController(
      viewportFraction: fraction,
      initialPage: _selectedPage,
    );
  }

  @override
  void dispose() {
    _time.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  /// The level the CTA opens: first unfinished, wrapping after completion.
  Level? get _nextLevel {
    final catalog = _catalog;
    final store = _store;
    if (catalog == null || store == null || catalog.levels.isEmpty) return null;
    final unlocked = store.unlockedLevel;
    if (unlocked <= catalog.levels.length) {
      return catalog.levels[unlocked - 1];
    }
    // Everything finished — offer a replay loop.
    return catalog.levels[(unlocked - 1) % catalog.levels.length];
  }

  bool get _allDone =>
      _catalog != null &&
      _store != null &&
      _store!.unlockedLevel > _catalog!.levels.length;

  Future<void> _play(Level level) async {
    final catalog = _catalog!;
    final unlockedBefore = _store?.unlockedLevel ?? 1;
    // Freeze every menu animation while the game is on top — covered
    // routes keep ticking otherwise, wasting frames behind the game.
    _time.stop();
    final exit = await Navigator.of(context).push<GameExit>(
      GameTransitions.zoomFade(
        GameScreen(
          level: level,
          hasNextLevel: level.number < catalog.levels.length,
        ),
      ),
    );
    if (!mounted) return;
    if (!_time.isAnimating) {
      _time.animateTo(
        _time.value + 86400,
        duration: const Duration(days: 1),
        curve: Curves.linear,
      );
    }
    setState(() {}); // refresh stars/unlocks

    // Progressed to a new furthest level → glide the carousel to it.
    final unlockedNow = _store?.unlockedLevel ?? 1;
    if (unlockedNow > unlockedBefore && _pageController != null) {
      final target = unlockedNow.clamp(1, catalog.levels.length) - 1;
      _selectedPage = target;
      _pageController!.animateToPage(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }

    switch (exit) {
      case GameExit.playNext:
        // Sequential next; falls back to the standard pick if at the end.
        final next = level.number < catalog.levels.length
            ? catalog.levels[level.number]
            : _nextLevel;
        if (next != null) _play(next);
      case GameExit.replay:
        _play(level);
      case GameExit.toMenu || null:
        break;
    }
  }

  void _toggleSound() {
    final store = _store;
    if (store == null) return;
    final enabled = !store.soundEnabled;
    store.setSoundEnabled(enabled);
    AudioController.instance.enabled = enabled;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: MenuBackground(animation: _time)),
          // Full width so the level carousel can bleed to the screen edges;
          // every other element centers itself.
          SafeArea(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final catalog = _catalog;
    final store = _store;
    final loaded = catalog != null && store != null;
    final selected = loaded
        ? catalog.levels[_selectedPage.clamp(0, catalog.levels.length - 1)]
        : null;
    final selectedLocked =
        loaded && selected != null && selected.number > store.unlockedLevel;
    final isReplay =
        loaded &&
        selected != null &&
        !selectedLocked &&
        selected.number < store.unlockedLevel;

    return Column(
      children: [
        const Spacer(flex: 2),
        GameTitle(animation: _time),
        const SizedBox(height: 6),
        Text(
          'PIXEL PAINT MACHINE',
          style: AppTypography.style(
            size: 13,
            weight: 600,
            color: AppColors.textDim,
          ),
        ),
        const Spacer(flex: 2),
        if (loaded)
          // Swipeable carousel over ALL levels — go back and replay any
          // past level; future levels show locked. Spans the full screen
          // width so neighbour cards peek instead of being clipped.
          SizedBox(
            height: 264,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controller = _controllerFor(constraints.maxWidth);
                return PageView.builder(
                  controller: controller,
                  itemCount: catalog.levels.length,
                  onPageChanged: (i) => setState(() => _selectedPage = i),
                  itemBuilder: (context, i) {
                    final level = catalog.levels[i];
                    final locked = level.number > store.unlockedLevel;
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) {
                        var delta = 0.0;
                        if (controller.position.haveDimensions) {
                          delta =
                              ((controller.page ?? _selectedPage.toDouble()) -
                                      i)
                                  .clamp(-1.0, 1.0)
                                  .toDouble();
                        }
                        final scale = 1 - delta.abs() * 0.14;
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: GestureDetector(
                        onTap: () {
                          if (i != _selectedPage) {
                            controller.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          } else if (!locked) {
                            _play(level);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: LevelPreviewCard(
                            level: level,
                            locked: locked,
                            completed: store.isCompleted(level.number),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        else
          const SizedBox(
            height: 264,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.candyPink),
            ),
          ),
        if (_allDone)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'All pictures painted — replay your favorites!',
              style: AppTypography.label(size: 13),
            ),
          ),
        const Spacer(flex: 2),
        if (selected != null)
          BouncyButton(
            onPressed: selectedLocked ? () {} : () => _play(selected),
            gradient: selectedLocked
                ? const LinearGradient(
                    colors: [Color(0xFF4A4370), Color(0xFF3A3458)],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.ctaTop, AppColors.ctaBottom],
                  ),
            pulse: !selectedLocked,
            shine: !selectedLocked,
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selectedLocked
                      ? Icons.lock_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: selectedLocked ? 24 : 30,
                ),
                const SizedBox(width: 6),
                Text(
                  selectedLocked ? 'LOCKED' : (isReplay ? 'REPLAY' : 'PLAY'),
                  style: AppTypography.button(size: 26),
                ),
              ],
            ),
          ),
        const Spacer(flex: 1),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconChip(
                icon: store?.soundEnabled ?? true
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                onTap: _toggleSound,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panel.withValues(alpha: 0.8),
      shape: const CircleBorder(side: BorderSide(color: Color(0x22FFFFFF))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.textSoft, size: 22),
        ),
      ),
    );
  }
}
