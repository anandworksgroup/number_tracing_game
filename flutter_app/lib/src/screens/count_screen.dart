// Count game: tap every object to count it, then pick how many there are.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app.dart';
import '../audio.dart';
import '../reward.dart';
import '../ui.dart';

class CountScreen extends StatefulWidget {
  const CountScreen({super.key, this.random});

  /// Injected in tests for repeatable rounds.
  final Random? random;

  @override
  State<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<CountScreen> {
  late final Random _rand = widget.random ?? Random();
  int _round = 0;
  int _n = 0;
  String _emoji = '🍎';
  final Map<int, int> _counted = {}; // object index -> number said
  List<int>? _options;
  final Map<int, int> _wrong = {}; // option -> shake counter
  bool _solved = false;
  Timer? _askTimer;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _askTimer?.cancel();
    super.dispose();
  }

  void _newRound() {
    var n = 0;
    do {
      n = 1 + _rand.nextInt(10);
    } while (n == _n);
    setState(() {
      _round++;
      _n = n;
      _emoji = rewardEmojis[_rand.nextInt(rewardEmojis.length)];
      _counted.clear();
      _options = null;
      _wrong.clear();
      _solved = false;
    });
    Audio.instance.speak('How many? Tap to count!');
  }

  void _count(int index) {
    if (_counted.containsKey(index)) return;
    final said = _counted.length + 1;
    setState(() => _counted[index] = said);
    Audio.instance
      ..play(Sfx.tap)
      ..sayNumber(said);
    if (said == _n) _askTimer = Timer(const Duration(milliseconds: 600), _ask);
  }

  void _ask() {
    if (!mounted) return;
    final opts = <int>{_n};
    while (opts.length < 3) {
      final d = _n + _rand.nextInt(5) - 2;
      if (d >= 1 && d <= 12) opts.add(d);
    }
    setState(() => _options = opts.toList()..shuffle(_rand));
    Audio.instance.speak('How many?');
  }

  Future<void> _answer(int v) async {
    if (_solved) return;
    final audio = Audio.instance;
    if (v != _n) {
      audio
        ..play(Sfx.oops)
        ..speak('Try again!');
      setState(() => _wrong[v] = (_wrong[v] ?? 0) + 1);
      return;
    }
    setState(() => _solved = true);
    ProgressScope.of(context).addTrophy();
    await showReward(context, title: 'Yes! $_n!', showAgain: false);
    if (mounted) _newRound();
  }

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).shortestSide;
    final objSize = (side * 0.18).clamp(64.0, 130.0);
    return Scaffold(
      body: Backdrop(
        child: Column(
          children: [
            TopBar(title: Text(_options == null ? 'Tap each one to count!' : 'How many?')),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    key: ValueKey('round-$_round'),
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < _n; i++)
                        PopIn(
                          delay: Duration(milliseconds: i * 60),
                          child: _CountObject(
                            key: Key('count-obj-$i'),
                            emoji: _emoji,
                            size: objSize,
                            number: _counted[i],
                            onTap: () => _count(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 116,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final v in _options ?? const <int>[])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: PopIn(
                        child: Shake(
                          trigger: _wrong[v] ?? 0,
                          child: Pressable(
                            key: Key('option-$v'),
                            semanticLabel: '$v',
                            onTap: () => _answer(v),
                            child: Container(
                              width: 92,
                              height: 92,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _solved && v == _n ? green : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: cardShadow,
                              ),
                              child: Text(
                                '$v',
                                style: TextStyle(
                                  fontSize: 52,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: _solved && v == _n ? Colors.white : purple,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountObject extends StatelessWidget {
  const _CountObject({super.key, required this.emoji, required this.size, required this.number, required this.onTap});
  final String emoji;
  final double size;
  final int? number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final counted = number != null;
    return Semantics(
      button: true,
      label: counted ? 'Counted $number' : 'Tap to count',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: counted ? 0.92 : 1,
          duration: const Duration(milliseconds: 150),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: counted ? const Color(0xFFFFF4C2) : const Color(0xBFFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: cardShadow,
                ),
                child: Emoji(emoji, size: size * 0.6),
              ),
              if (counted)
                Positioned(
                  top: -10,
                  right: -8,
                  child: PopIn(
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: purple, shape: BoxShape.circle),
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
