// Sound effects and spoken numbers.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

const numberWords = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', //
  'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen',
  'eighteen', 'nineteen', 'twenty',
];

enum Sfx { tap, tick, ding, oops, pop, win }

class Audio {
  Audio._();
  static final Audio instance = Audio._();

  bool sound = true;
  bool voice = true;

  /// Set in tests so no platform channels are touched.
  @visibleForTesting
  static bool enabled = true;

  final Map<Sfx, AudioPlayer> _players = {};
  FlutterTts? _tts;

  Future<void> init() async {
    if (!enabled) return;
    try {
      for (final s in Sfx.values) {
        final p = AudioPlayer(playerId: 'sfx_${s.name}');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/${s.name}.wav'));
        _players[s] = p;
      }
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
      await tts.setPitch(1.25);
      _tts = tts;
    } catch (e) {
      debugPrint('Audio unavailable: $e');
    }
  }

  void play(Sfx s) {
    if (!sound || !enabled) return;
    final p = _players[s];
    if (p == null) return;
    p.stop().then((_) => p.resume()).catchError((Object _) {});
  }

  void speak(String text) {
    if (!voice || !enabled) return;
    final tts = _tts;
    if (tts == null) return;
    tts.stop().then((_) => tts.speak(text)).catchError((Object _) => null);
  }

  void sayNumber(int n) => speak(n < numberWords.length ? numberWords[n] : '$n');
}
