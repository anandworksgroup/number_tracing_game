// Stars and settings saved on the device.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';

class Progress extends ChangeNotifier {
  Progress._(this._prefs);

  static const _key = 'trace123';
  final SharedPreferences _prefs;

  Map<int, int> stars = {};
  int trophies = 0;
  bool sound = true;
  bool voice = true;

  static Future<Progress> load() async {
    final p = Progress._(await SharedPreferences.getInstance());
    try {
      final raw = p._prefs.getString(_key);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        p.stars = {
          for (final e in (m['stars'] as Map<String, dynamic>? ?? {}).entries) int.parse(e.key): e.value as int,
        };
        p.trophies = m['trophies'] as int? ?? 0;
        p.sound = m['sound'] as bool? ?? true;
        p.voice = m['voice'] as bool? ?? true;
      }
    } catch (_) {
      // Corrupt data: start fresh.
    }
    p._applySettings();
    return p;
  }

  int get totalStars => stars.values.fold(0, (a, b) => a + b) + trophies;

  void recordTrace(int n, int earned) {
    if (earned <= (stars[n] ?? 0)) return;
    stars[n] = earned;
    _save();
  }

  void addTrophy() {
    trophies++;
    _save();
  }

  void toggleSound() {
    sound = !sound;
    _save();
  }

  void toggleVoice() {
    voice = !voice;
    _save();
  }

  void reset() {
    stars = {};
    trophies = 0;
    _save();
  }

  void _applySettings() {
    Audio.instance
      ..sound = sound
      ..voice = voice;
  }

  void _save() {
    _applySettings();
    notifyListeners();
    _prefs.setString(
      _key,
      jsonEncode({
        'stars': {for (final e in stars.entries) '${e.key}': e.value},
        'trophies': trophies,
        'sound': sound,
        'voice': voice,
      }),
    );
  }
}
