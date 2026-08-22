/// Every sound effect in the game, mapped to its generated asset.
enum Sfx {
  tap('audio/tap.wav', pool: 3),
  tick('audio/tick.wav', pool: 6),
  whoosh('audio/whoosh.wav', pool: 3),
  pop('audio/pop.wav', pool: 4),
  bottlePop('audio/bottle_pop.wav', pool: 3),
  error('audio/error.wav'),
  win('audio/win.wav'),
  ui('audio/ui.wav'),
  sweep('audio/sweep.wav');

  const Sfx(this.asset, {this.pool = 2});

  /// Path relative to the assets/ folder (AssetSource convention).
  final String asset;

  /// How many simultaneous players to keep warm for this sound.
  final int pool;
}
