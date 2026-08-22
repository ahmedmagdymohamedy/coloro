import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models/level.dart';

/// Discovers levels by scanning the asset bundle, so adding a new level is
/// just dropping an image into `assets/levels/`.
///
/// Difficulty per level comes from `assets/levels/levels.json` when the file
/// lists it, otherwise from [autoGridSize]/[autoMaxColors] — a gentle ramp
/// that makes later levels bigger and more colorful.
class LevelCatalog {
  LevelCatalog._(this.levels);

  final List<Level> levels;

  static const _dir = 'assets/levels/';
  static const _imageExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

  static LevelCatalog? _cached;

  static Future<LevelCatalog> load() async {
    if (_cached != null) return _cached!;

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((p) =>
            p.startsWith(_dir) &&
            _imageExtensions.any((e) => p.toLowerCase().endsWith(e)))
        .toList()
      ..sort(_naturalCompare);

    final overrides = await _loadOverrides();

    final levels = <Level>[];
    for (var i = 0; i < paths.length; i++) {
      final number = i + 1;
      final fileName = paths[i].substring(_dir.length);
      final o = overrides[fileName];
      levels.add(Level(
        number: number,
        assetPath: paths[i],
        gridSize: (o?['gridSize'] as num?)?.toInt() ?? autoGridSize(number),
        maxColors: (o?['maxColors'] as num?)?.toInt() ?? autoMaxColors(number),
        name: o?['name'] as String?,
        hard: o?['hard'] as bool? ?? false,
        shuffleWindow: (o?['shuffleWindow'] as num?)?.toInt() ?? 1,
        dealSeed: (o?['dealSeed'] as num?)?.toInt() ?? 0,
      ));
    }
    return _cached = LevelCatalog._(levels);
  }

  /// Automatic difficulty ramp: 24 cells on level 1 up to 40 late game.
  static int autoGridSize(int number) => (22 + number * 2).clamp(24, 40);

  /// 4 colors early, up to 8 late game.
  static int autoMaxColors(int number) => (3 + number).clamp(4, 8);

  static Future<Map<String, Map<String, dynamic>>> _loadOverrides() async {
    try {
      final raw = await rootBundle.loadString('${_dir}levels.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final levels = json['levels'] as Map<String, dynamic>? ?? {};
      return levels.map(
        (k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()),
      );
    } catch (_) {
      return {};
    }
  }

  /// Sorts "2.png" before "10.png".
  static int _naturalCompare(String a, String b) {
    int? num(String p) {
      final name = p.split('/').last.split('.').first;
      return int.tryParse(name);
    }

    final na = num(a), nb = num(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }
}
