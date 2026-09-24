// Generates the short sound effects in assets/sounds/ as 16-bit mono WAV files.
//
//   dart run tool/gen_sounds.dart
//
// They mirror the synthesized sounds of the web version, so no third-party
// audio is needed.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const rate = 22050;

enum Wave { sine, triangle, square, sawtooth }

class Tone {
  const Tone(this.freq, {this.at = 0, this.dur = 0.15, this.wave = Wave.sine, this.vol = 0.2, this.slide = 1});
  final double freq, at, dur, vol, slide;
  final Wave wave;
}

double osc(Wave w, double phase) {
  final p = phase - phase.floorToDouble();
  switch (w) {
    case Wave.sine:
      return sin(2 * pi * p);
    case Wave.triangle:
      return 1 - 4 * (p - 0.5).abs();
    case Wave.square:
      return p < 0.5 ? 1 : -1;
    case Wave.sawtooth:
      return 2 * p - 1;
  }
}

Float64List render(List<Tone> tones) {
  final end = tones.map((t) => t.at + t.dur).reduce(max) + 0.03;
  final out = Float64List((end * rate).ceil());
  for (final t in tones) {
    final start = (t.at * rate).round();
    final n = (t.dur * rate).round();
    var phase = 0.0;
    for (var i = 0; i < n && start + i < out.length; i++) {
      final k = i / n;
      // Exponential pitch slide, like exponentialRampToValueAtTime.
      final f = t.freq * pow(t.slide, k);
      phase += f / rate;
      // Quick attack, exponential decay.
      final attack = min(1.0, i / (0.01 * rate));
      final env = attack * pow(0.0005, k);
      out[start + i] += osc(t.wave, phase) * t.vol * env;
    }
  }
  return out;
}

void writeWav(String path, Float64List samples) {
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 2.2).clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
}

void main() {
  final sounds = <String, List<Tone>>{
    'tap': [const Tone(660, dur: 0.08, wave: Wave.triangle, vol: 0.15)],
    'tick': [const Tone(620, dur: 0.05, vol: 0.06)],
    'ding': [const Tone(880, dur: 0.25, wave: Wave.triangle), const Tone(1320, at: 0.08, dur: 0.3, vol: 0.12)],
    'oops': [const Tone(220, dur: 0.25, wave: Wave.sawtooth, vol: 0.08, slide: 0.6)],
    'pop': [const Tone(900, dur: 0.12, wave: Wave.square, vol: 0.08, slide: 0.3)],
    'win': [
      for (final (i, f) in [523.0, 659.0, 784.0, 1047.0].indexed) Tone(f, at: i * 0.11, dur: 0.3, wave: Wave.triangle),
    ],
  };
  Directory('assets/sounds').createSync(recursive: true);
  sounds.forEach((name, tones) {
    writeWav('assets/sounds/$name.wav', render(tones));
    stdout.writeln('assets/sounds/$name.wav');
  });
}
