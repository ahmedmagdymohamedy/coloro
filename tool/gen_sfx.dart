// Generates all game sound effects as WAV files into assets/audio/.
// Run with: dart run tool/gen_sfx.dart
//
// Every sound is synthesized from scratch (sine partials, noise bursts,
// envelopes) so the game ships with zero third-party audio.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final out = Directory('assets/audio');
  out.createSync(recursive: true);

  save('tap.wav', tap());
  save('tick.wav', tick());
  save('whoosh.wav', whoosh());
  save('pop.wav', pop());
  save('bottle_pop.wav', bottlePop());
  save('error.wav', errorBuzz());
  save('win.wav', winFanfare());
  save('ui.wav', uiClick());
  save('sweep.wav', sweep());

  stdout.writeln('Generated ${out.listSync().length} sfx files.');
}

// ---------------------------------------------------------------------------
// Sound recipes
// ---------------------------------------------------------------------------

/// Soft blip for picking a bottle up.
List<double> tap() {
  final n = ms(80);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final f = 620 + 340 * (i / n);
    final env = attackDecay(i, n, attack: 0.02, curve: 5);
    return 0.55 * env * math.sin(2 * math.pi * f * t);
  });
}

/// Tiny pixel-landing pop. Pitched up at runtime as combos build.
List<double> tick() {
  final n = ms(50);
  final rnd = math.Random(7);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final env = attackDecay(i, n, attack: 0.01, curve: 9);
    final body = math.sin(2 * math.pi * 1050 * t) * 0.6 +
        math.sin(2 * math.pi * 2100 * t) * 0.2;
    final click = i < ms(4) ? (rnd.nextDouble() * 2 - 1) * 0.25 : 0.0;
    return 0.5 * env * (body + click);
  });
}

/// Soft, dark little puff for a bottle hop — deliberately gentle, it plays
/// on every launch/dispatch.
List<double> whoosh() {
  final n = ms(150);
  final rnd = math.Random(3);
  final raw = List.generate(n, (_) => rnd.nextDouble() * 2 - 1);
  // Double lowpass → no hiss, just a breathy thump.
  final smooth = lowpass(lowpass(raw, 0.10), 0.10);
  return List.generate(n, (i) {
    final p = i / n;
    final env = math.pow(math.sin(math.pi * p), 2).toDouble();
    return 0.30 * env * smooth[i] * 3.2;
  });
}

/// Quick bubble pop.
List<double> pop() {
  final n = ms(110);
  final rnd = math.Random(11);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final env = attackDecay(i, n, attack: 0.005, curve: 8);
    final f = 420 - 260 * (i / n); // falling thump
    final thump = math.sin(2 * math.pi * f * t);
    final burst = i < ms(14) ? (rnd.nextDouble() * 2 - 1) * 0.6 : 0.0;
    return 0.6 * env * (thump * 0.8 + burst);
  });
}

/// Bigger celebratory pop when a bottle finishes draining.
List<double> bottlePop() {
  final base = pop();
  final chimeN = ms(200);
  final total = List<double>.from(base)..addAll(List.filled(chimeN, 0));
  for (var i = 0; i < chimeN; i++) {
    final t = i / sampleRate;
    final env = attackDecay(i, chimeN, attack: 0.02, curve: 6);
    final chime = math.sin(2 * math.pi * 1244 * t) * 0.5 +
        math.sin(2 * math.pi * 1866 * t) * 0.25;
    total[ms(30) + i] += 0.4 * env * chime;
  }
  return total;
}

/// Gentle "not now" wobble when no slot is free.
List<double> errorBuzz() {
  final n = ms(190);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final env = attackDecay(i, n, attack: 0.03, curve: 4);
    final vib = 1 + 0.06 * math.sin(2 * math.pi * 22 * t);
    final f = 165.0 * vib;
    final tri = 2 / math.pi * math.asin(math.sin(2 * math.pi * f * t));
    return 0.4 * env * tri;
  });
}

/// Sparkling arpeggio fanfare for level completion.
List<double> winFanfare() {
  final total = ms(1500);
  final out = List<double>.filled(total, 0);
  final notes = [523.25, 659.25, 783.99, 1046.5]; // C5 E5 G5 C6
  for (var k = 0; k < notes.length; k++) {
    addNote(out, start: ms(120) * k, len: ms(700), freq: notes[k], gain: 0.32);
  }
  // Final chord swell.
  for (final f in [523.25, 659.25, 783.99, 1046.5]) {
    addNote(out, start: ms(520), len: ms(950), freq: f, gain: 0.16);
  }
  // Glitter on top.
  final rnd = math.Random(5);
  for (var s = 0; s < 10; s++) {
    final f = 2000.0 + rnd.nextInt(1800);
    addNote(out,
        start: ms(400) + ms(80) * s, len: ms(140), freq: f, gain: 0.06);
  }
  return out;
}

/// Softer click for menu buttons.
List<double> uiClick() {
  final n = ms(70);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final env = attackDecay(i, n, attack: 0.02, curve: 7);
    return 0.45 * env * math.sin(2 * math.pi * 480 * t);
  });
}

/// Rising shimmer for the completion shine sweep.
List<double> sweep() {
  final n = ms(500);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final p = i / n;
    final f = 500 + 1600 * p * p;
    final env = math.sin(math.pi * p) * 0.8;
    return 0.35 * env * math.sin(2 * math.pi * f * t);
  });
}

// ---------------------------------------------------------------------------
// Synth helpers
// ---------------------------------------------------------------------------

int ms(int milliseconds) => sampleRate * milliseconds ~/ 1000;

double attackDecay(int i, int n, {double attack = 0.02, double curve = 6}) {
  final p = i / n;
  if (p < attack) return p / attack;
  final d = (p - attack) / (1 - attack);
  return math.exp(-curve * d);
}

List<double> lowpass(List<double> x, double alpha) {
  final y = List<double>.filled(x.length, 0);
  var prev = 0.0;
  for (var i = 0; i < x.length; i++) {
    prev = prev + alpha * (x[i] - prev);
    y[i] = prev;
  }
  return y;
}

void addNote(List<double> out,
    {required int start,
    required int len,
    required double freq,
    required double gain}) {
  for (var i = 0; i < len && start + i < out.length; i++) {
    final t = i / sampleRate;
    final env = attackDecay(i, len, attack: 0.03, curve: 4);
    final s = math.sin(2 * math.pi * freq * t) +
        0.3 * math.sin(2 * math.pi * freq * 2 * t);
    out[start + i] += gain * env * s;
  }
}

void save(String name, List<double> samples) {
  final n = samples.length;
  final dataSize = n * 2;
  final bytes = ByteData(44 + dataSize);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  str(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  File('assets/audio/$name').writeAsBytesSync(bytes.buffer.asUint8List());
}
