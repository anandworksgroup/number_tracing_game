// "Great job!" popup: stars, confetti, and objects counted out loud.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'audio.dart';
import 'ui.dart';

const rewardEmojis = ['🍎', '⭐', '🐟', '🎈', '🍓', '🐥', '🌸', '🚗', '🍪', '🦋', '🐞', '🍩'];

enum RewardChoice { again, next }

Future<RewardChoice?> showReward(
  BuildContext context, {
  required String title,
  int stars = 3,
  int? count,
  String emoji = '🍎',
  bool showAgain = true,
}) {
  return showGeneralDialog<RewardChoice>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x73281A5A),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) => Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RewardCard(title: title, stars: stars, count: count, emoji: emoji, showAgain: showAgain),
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ],
    ),
  );
}

class RewardCard extends StatefulWidget {
  const RewardCard({
    super.key,
    required this.title,
    required this.stars,
    required this.count,
    required this.emoji,
    required this.showAgain,
  });

  final String title;
  final int stars;
  final int? count;
  final String emoji;
  final bool showAgain;

  @override
  State<RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<RewardCard> {
  final _timers = <Timer>[];
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    final audio = Audio.instance..play(Sfx.win);
    final count = widget.count;
    if (count == 0) {
      _timers.add(Timer(const Duration(milliseconds: 700), () => audio.speak('Zero! Nothing in the basket.')));
      return;
    }
    audio.speak(widget.title);
    for (var i = 1; i <= (count ?? 0); i++) {
      _timers.add(
        Timer(Duration(milliseconds: 900 + i * 700), () {
          if (!mounted) return;
          setState(() => _shown = i);
          audio
            ..play(Sfx.tap)
            ..sayNumber(i);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _close(RewardChoice choice) {
    for (final t in _timers) {
      t.cancel();
    }
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    return PopIn(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 1; i <= 3; i++)
                    PopIn(
                      delay: Duration(milliseconds: 150 * i),
                      child: Icon(
                        Icons.star_rounded,
                        size: i == 2 ? 72 : 56,
                        color: i <= widget.stars ? gold : const Color(0xFFE6E0F5),
                      ),
                    ),
                ],
              ),
              Text(
                widget.title,
                key: const Key('reward-title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: purple, height: 1.1),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: widget.count == 0
                    ? const Column(
                        children: [
                          Emoji('🧺', size: 52),
                          Text(
                            'zero: nothing here!',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
                          ),
                        ],
                      )
                    : Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (var i = 1; i <= _shown; i++)
                            PopIn(
                              child: _CountedItem(emoji: widget.emoji, n: i),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showAgain) ...[
                    _ActionButton(
                      key: const Key('reward-again'),
                      color: blue,
                      icon: Icons.replay_rounded,
                      label: 'Again',
                      onTap: () => _close(RewardChoice.again),
                    ),
                    const SizedBox(width: 16),
                  ],
                  _ActionButton(
                    key: const Key('reward-next'),
                    color: red,
                    icon: Icons.arrow_forward_rounded,
                    label: 'Next',
                    onTap: () => _close(RewardChoice.next),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountedItem extends StatelessWidget {
  const _CountedItem({required this.emoji, required this.n});
  final String emoji;
  final int n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Emoji(emoji, size: 38),
          Positioned(
            right: -4,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(color: purple, borderRadius: BorderRadius.circular(99)),
              child: Text(
                '$n',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({super.key, required this.color, required this.icon, required this.label, required this.onTap});
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 6,
      semanticLabel: label,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: darker(color), offset: const Offset(0, 8))],
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      ),
    );
  }
}

// ---------- confetti ----------

class _Bit {
  _Bit(this.pos, this.vel, this.rot, this.spin, this.size, this.color);
  Offset pos;
  Offset vel;
  double rot;
  final double spin;
  final Size size;
  final Color color;
}

class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 140});
  final int count;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _bits = <_Bit>[];
  Size _size = Size.zero;
  bool _spawned = false;
  Duration? _last;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _spawn() {
    final r = Random();
    for (var i = 0; i < widget.count; i++) {
      _bits.add(
        _Bit(
          Offset(_size.width / 2 + (r.nextDouble() - 0.5) * 120, _size.height * 0.45),
          Offset((r.nextDouble() - 0.5) * 14, -r.nextDouble() * 14 - 4),
          r.nextDouble() * pi,
          (r.nextDouble() - 0.5) * 0.3,
          Size(6 + r.nextDouble() * 6, 4 + r.nextDouble() * 4),
          HSLColor.fromAHSL(1, r.nextDouble() * 360, 0.9, 0.6).toColor(),
        ),
      );
    }
  }

  void _tick(Duration elapsed) {
    // Steps are in 60 fps frames, so the confetti moves at the same speed at any frame rate.
    final k = _last == null ? 1.0 : min(3.0, (elapsed - _last!).inMicroseconds / 1e6 * 60);
    _last = elapsed;
    if (_size == Size.zero) return;
    if (!_spawned) {
      _spawned = true;
      _spawn();
    }
    for (final b in _bits) {
      b.pos += b.vel * k;
      b.vel = Offset(b.vel.dx * pow(0.99, k), b.vel.dy + 0.35 * k);
      b.rot += b.spin * k;
    }
    _bits.removeWhere((b) => b.pos.dy > _size.height + 30);
    if (_bits.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        return CustomPaint(size: _size, painter: _ConfettiPainter(_bits));
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits);
  final List<_Bit> bits;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      canvas.save();
      canvas.translate(b.pos.dx, b.pos.dy);
      canvas.rotate(b.rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: b.size.width, height: b.size.height),
        Paint()..color = b.color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
