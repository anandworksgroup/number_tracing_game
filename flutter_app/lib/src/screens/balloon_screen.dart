// Balloon pop: pop only the balloons showing the target number.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../audio.dart';
import '../reward.dart';
import '../ui.dart';

const _colors = [red, orange, green, blue, Color(0xFFA259FF), Color(0xFFFF6FB5)];
const goal = 5;
const _maxValue = 10;
const _balloonW = 84.0;
const _balloonH = 104.0;

class _Balloon {
  _Balloon(this.id, this.value, this.color, this.x, this.y, this.vy, this.phase);
  final int id;
  final int value;
  final Color color;
  final double x;
  double y;
  final double vy;
  final double phase;
  Duration? poppedAt;
  int wobble = 0;
}

class BalloonScreen extends StatefulWidget {
  const BalloonScreen({super.key, this.random});

  /// Injected in tests for repeatable games.
  final Random? random;

  @override
  State<BalloonScreen> createState() => _BalloonScreenState();
}

class _BalloonScreenState extends State<BalloonScreen> with SingleTickerProviderStateMixin {
  late final Random _rand = widget.random ?? Random();
  late final Ticker _ticker = createTicker(_tick);
  final _balloons = <_Balloon>[];
  Size _sky = Size.zero;
  Duration _now = Duration.zero;
  Duration? _last;
  double _spawnIn = 0;
  int _nextId = 0;
  int _target = -1;
  int _popped = 0;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _newTarget();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _newTarget() {
    var t = 0;
    do {
      t = _rand.nextInt(_maxValue + 1);
    } while (t == _target);
    _target = t;
    _popped = 0;
    _announce();
  }

  void _announce() => Audio.instance.speak('Pop the number ${numberWords[_target]}!');

  void _spawn() {
    var v = _target;
    if (_rand.nextDouble() >= 0.4) {
      while (v == _target) {
        v = _rand.nextInt(_maxValue + 1);
      }
    }
    _balloons.add(
      _Balloon(
        _nextId++,
        v,
        _colors[_rand.nextInt(_colors.length)],
        8 + _rand.nextDouble() * max(0, _sky.width - _balloonW - 16),
        _sky.height + 10,
        45 + _rand.nextDouble() * 45,
        _rand.nextDouble() * 6,
      ),
    );
  }

  void _tick(Duration elapsed) {
    final dt = _last == null ? 0.0 : min(0.05, (elapsed - _last!).inMicroseconds / 1e6);
    _last = elapsed;
    _now = elapsed;
    if (_sky == Size.zero) return;
    if (_running) {
      _spawnIn -= dt;
      if (_spawnIn <= 0) {
        _spawn();
        _spawnIn = 0.9 + _rand.nextDouble() * 0.6;
      }
    }
    for (final b in _balloons) {
      if (b.poppedAt == null) b.y -= b.vy * dt;
    }
    _balloons.removeWhere(
      (b) => b.y < -_balloonH - 40 || (b.poppedAt != null && elapsed - b.poppedAt! > const Duration(milliseconds: 250)),
    );
    setState(() {});
  }

  Future<void> _hit(_Balloon b) async {
    if (b.poppedAt != null) return;
    final audio = Audio.instance;
    if (b.value != _target) {
      audio
        ..play(Sfx.oops)
        ..sayNumber(b.value);
      setState(() => b.wobble++);
      return;
    }
    audio
      ..play(Sfx.pop)
      ..sayNumber(b.value);
    setState(() {
      b.poppedAt = _now;
      _popped++;
    });
    if (_popped >= goal && _running) {
      _running = false;
      ProgressScope.of(context).addTrophy();
      await showReward(context, title: 'Super popping!', showAgain: false);
      if (!mounted) return;
      setState(() {
        _balloons.clear();
        _running = true;
        _spawnIn = 0;
        _newTarget();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: Column(
          children: [
            TopBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pop the '),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      '$_target',
                      key: const Key('pop-target'),
                      style: const TextStyle(color: red),
                    ),
                  ),
                ],
              ),
              trailing: RoundButton(
                label: 'Say it again',
                onTap: _announce,
                child: const Icon(Icons.volume_up_rounded, color: ink, size: 28),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < goal; i++)
                    Opacity(
                      opacity: i < _popped ? 1 : 0.25,
                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Emoji('🎈', size: 24)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                key: const Key('sky'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFBFEAFF), Color(0xFFEAFAFF)],
                  ),
                  boxShadow: cardShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, box) {
                    _sky = box.biggest;
                    final t = _now.inMicroseconds / 1e6;
                    return Stack(
                      children: [
                        for (final b in _balloons)
                          Positioned(
                            key: ValueKey(b.id),
                            left: b.x + sin(t / 0.7 + b.phase) * 10,
                            top: b.y,
                            child: GestureDetector(
                              key: Key('balloon-${b.value}-${b.id}'),
                              onTapDown: (_) => _hit(b),
                              child: Shake(
                                trigger: b.wobble,
                                child: _BalloonView(balloon: b, now: _now),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalloonView extends StatelessWidget {
  const _BalloonView({required this.balloon, required this.now});
  final _Balloon balloon;
  final Duration now;

  @override
  Widget build(BuildContext context) {
    final popped = balloon.poppedAt;
    final k = popped == null ? 0.0 : ((now - popped).inMilliseconds / 200).clamp(0.0, 1.0);
    return Opacity(
      opacity: 1 - k,
      child: SizedBox(
        width: _balloonW,
        height: _balloonH + 36,
        child: Stack(
          children: [
            Positioned(
              left: _balloonW / 2 - 1,
              top: _balloonH - 6,
              child: Container(width: 2, height: 40, color: const Color(0x40000000)),
            ),
            Transform.scale(
              scale: 1 + 0.6 * k,
              child: Container(
                width: _balloonW,
                height: _balloonH - 4,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.elliptical(_balloonW / 2, 55),
                    bottom: Radius.elliptical(_balloonW / 2, 45),
                  ),
                  gradient: RadialGradient(
                    center: const Alignment(-0.36, -0.44),
                    radius: 0.6,
                    colors: [
                      Color.lerp(balloon.color, Colors.white, 0.55)!,
                      Color.lerp(balloon.color, Colors.white, 0.55)!,
                      balloon.color,
                    ],
                    stops: const [0, 0.2, 0.21],
                  ),
                ),
                child: Text(
                  '${balloon.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 2))],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
