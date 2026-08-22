import '../domain/models/level_result.dart';
import '../domain/models/paint_bottle.dart';

/// One-shot gameplay notifications the screen reacts to with sound,
/// haptics and VFX. State itself lives in [GameController].
sealed class GameEvent {
  const GameEvent();
}

/// A bottle left the tray and should fly to [slotIndex].
class BottleLaunched extends GameEvent {
  const BottleLaunched(this.bottle, this.column, this.slotIndex);

  final PaintBottle bottle;
  final int column;
  final int slotIndex;
}

/// The player tapped a bottle but no slot is free.
class LaunchRefused extends GameEvent {
  const LaunchRefused(this.column);

  final int column;
}

/// A pixel starts travelling from [slotIndex] to [cellIndex].
class CellFillStarted extends GameEvent {
  const CellFillStarted(this.cellIndex, this.colorIndex, this.slotIndex);

  final int cellIndex;
  final int colorIndex;
  final int slotIndex;
}

/// A bottle became full and popped in its slot.
class BottleEmptied extends GameEvent {
  const BottleEmptied(this.slotIndex, this.colorIndex);

  final int slotIndex;
  final int colorIndex;
}

/// A docked bottle jammed (true) or resumed spraying (false): its color
/// is / is no longer missing from the picture's paintable edge.
class SlotStuckChanged extends GameEvent {
  const SlotStuckChanged(this.slotIndex, this.stuck);

  final int slotIndex;
  final bool stuck;
}

/// Every slot is blocked by a stuck bottle — the machine jammed.
class LevelFailed extends GameEvent {
  const LevelFailed();
}

/// Every pixel has landed — the picture is complete.
class LevelCompleted extends GameEvent {
  const LevelCompleted(this.result);

  final LevelResult result;
}
