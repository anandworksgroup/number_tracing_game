import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../audio.dart';
import '../reward.dart';
import '../trace_board.dart';
import '../trace_logic.dart';
import '../ui.dart';
import 'picker_screen.dart' show maxNumber;

class TraceScreen extends StatefulWidget {
  const TraceScreen({super.key, required this.start});
  final int start;

  @override
  State<TraceScreen> createState() => _TraceScreenState();
}

class _TraceScreenState extends State<TraceScreen> {
  late TraceLogic _logic;
  Color _color = crayons.first;
  int _demoKey = 0;
  int _shakeKey = 0;
  int _lastTick = 0;
  Timer? _rewardTimer;

  @override
  void initState() {
    super.initState();
    _load(widget.start);
  }

  @override
  void dispose() {
    _rewardTimer?.cancel();
    super.dispose();
  }

  void _load(int n) {
    _rewardTimer?.cancel();
    final audio = Audio.instance;
    _logic = TraceLogic(n)
      ..onMiss = () {
        setState(() => _demoKey++);
        audio.speak('Start at the green dot');
      }
      ..onStray = () {
        audio.play(Sfx.oops);
        HapticFeedback.lightImpact();
        setState(() => _shakeKey++);
      }
      ..onAdvance = (i) {
        if (i ~/ 8 != _lastTick ~/ 8) audio.play(Sfx.tick);
        _lastTick = i;
      }
      ..onStrokeDone = (_) {
        audio.play(Sfx.ding);
        _lastTick = 0;
        setState(() => _demoKey++);
      }
      ..onComplete = _complete;
    _lastTick = 0;
    audio.sayNumber(n);
  }

  void _open(int n) => setState(() => _load(n));

  void _complete(int strays) {
    final n = _logic.number;
    final stars = starsFor(strays);
    ProgressScope.of(context).recordTrace(n, stars);
    // Short pause so the finished number is visible before the popup.
    _rewardTimer = Timer(const Duration(milliseconds: 350), () async {
      // Skip the popup if the child already left this screen.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
      final word = numberWords[n];
      final choice = await showReward(
        context,
        title: '${word[0].toUpperCase()}${word.substring(1)}!',
        stars: stars,
        count: n,
        emoji: rewardEmojis[n % rewardEmojis.length],
      );
      if (!mounted) return;
      switch (choice) {
        case RewardChoice.again:
          _open(n);
        case RewardChoice.next:
          _open(n >= maxNumber ? 0 : n + 1);
        case null:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _logic.number;
    return Scaffold(
      body: Backdrop(
        child: Column(
          children: [
            TopBar(
              title: Text('$n · ${numberWords[n]}', key: const Key('trace-title')),
              trailing: RoundButton(
                label: 'Say the number',
                onTap: () => Audio.instance.sayNumber(n),
                child: const Icon(Icons.volume_up_rounded, color: ink, size: 28),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Shake(
                trigger: _shakeKey,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF5),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFFFE9A8), width: 4),
                          boxShadow: cardShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: TraceBoard(
                            key: const Key('trace-board'),
                            logic: _logic,
                            color: _color,
                            demoKey: _demoKey,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SideButton(
                          key: const Key('trace-prev'),
                          icon: Icons.chevron_left_rounded,
                          label: 'Previous number',
                          onTap: () => _open(n <= 0 ? maxNumber : n - 1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _SideButton(
                          key: const Key('trace-next'),
                          icon: Icons.chevron_right_rounded,
                          label: 'Next number',
                          onTap: () => _open(n >= maxNumber ? 0 : n + 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                RoundButton(label: 'Show me', onTap: () => setState(() => _demoKey++), child: const Emoji('👆')),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in crayons)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _Crayon(color: c, active: c == _color, onTap: () => setState(() => _color = c)),
                          ),
                        ),
                    ],
                  ),
                ),
                RoundButton(
                  label: 'Start over',
                  onTap: () => _open(n),
                  child: const Icon(Icons.refresh_rounded, color: ink, size: 30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: 44,
        height: 88,
        decoration: BoxDecoration(color: const Color(0xB3FFFFFF), borderRadius: BorderRadius.circular(22)),
        child: Icon(icon, size: 40, color: ink),
      ),
    );
  }
}

class _Crayon extends StatelessWidget {
  const _Crayon({required this.color, required this.active, required this.onTap});
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Crayon colour',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, active ? -8 : 0, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 32),
          child: AspectRatio(
            aspectRatio: 28 / 44,
            child: CustomPaint(painter: _CrayonPainter(color)),
          ),
        ),
      ),
    );
  }
}

class _CrayonPainter extends CustomPainter {
  _CrayonPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h * 0.28)
      ..lineTo(w, h - 6)
      ..quadraticBezierTo(w, h, w - 6, h)
      ..lineTo(6, h)
      ..quadraticBezierTo(0, h, 0, h - 6)
      ..lineTo(0, h * 0.28)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(Rect.fromLTWH(0, h - 6, w, 6), Paint()..color = darker(color, 0.15));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrayonPainter old) => old.color != color;
}
