import 'dart:math';

import 'package:flutter/material.dart';

import '../app.dart';
import '../audio.dart';
import '../ui.dart';
import 'balloon_screen.dart';
import 'count_screen.dart';
import 'picker_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return Scaffold(
      body: Backdrop(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: cardShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: gold, size: 28),
                      const SizedBox(width: 6),
                      Text(
                        '${progress.totalStars}',
                        key: const Key('home-stars'),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _Toggle(
                  on: progress.sound,
                  label: 'Sound effects',
                  icon: Icons.volume_up_rounded,
                  offIcon: Icons.volume_off_rounded,
                  onTap: progress.toggleSound,
                ),
                const SizedBox(width: 10),
                _Toggle(
                  on: progress.voice,
                  label: 'Voice',
                  icon: Icons.record_voice_over_rounded,
                  offIcon: Icons.voice_over_off_rounded,
                  onTap: () {
                    progress.toggleVoice();
                    Audio.instance.speak('Hello!');
                  },
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Logo(),
                    const Text(
                      'Trace & Count',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 24),
                    BigButton(
                      key: const Key('go-trace'),
                      color: red,
                      emoji: '✏️',
                      label: 'Trace',
                      onTap: () => Navigator.of(context).push(route(const PickerScreen())),
                    ),
                    const SizedBox(height: 22),
                    BigButton(
                      key: const Key('go-count'),
                      color: blue,
                      emoji: '🍎',
                      label: 'Count',
                      onTap: () => Navigator.of(context).push(route(const CountScreen())),
                    ),
                    const SizedBox(height: 22),
                    BigButton(
                      key: const Key('go-pop'),
                      color: orange,
                      emoji: '🎈',
                      label: 'Pop',
                      onTap: () => Navigator.of(context).push(route(const BalloonScreen())),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => _confirmReset(context),
              child: const Text(
                'Parents: reset progress',
                style: TextStyle(color: Color(0x993B2A7A), decoration: TextDecoration.underline, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final progress = ProgressScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all stars?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok ?? false) progress.reset();
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.on,
    required this.label,
    required this.icon,
    required this.offIcon,
    required this.onTap,
  });
  final bool on;
  final String label;
  final IconData icon;
  final IconData offIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: RoundButton(
        label: '$label ${on ? 'on' : 'off'}',
        onTap: onTap,
        child: Icon(on ? icon : offIcon, color: on ? purple : Colors.grey, size: 28),
      ),
    );
  }
}

/// Bobbing "123" logo with white outlines.
class Logo extends StatefulWidget {
  const Logo({super.key});

  @override
  State<Logo> createState() => _LogoState();
}

class _LogoState extends State<Logo> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = min(160.0, MediaQuery.sizeOf(context).width * 0.28);
    const colors = [red, green, blue];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(0, -10 * (0.5 - 0.5 * cos(2 * pi * (_c.value - i * 0.125)))),
              child: Transform.rotate(
                angle: -4 * pi / 180 * (0.5 - 0.5 * cos(2 * pi * (_c.value - i * 0.125))),
                child: OutlinedText('${i + 1}', size: size, color: colors[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, required this.size, required this.color, this.stroke = 6});
  final String text;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w800, height: 1);
    return Stack(
      children: [
        Text(
          text,
          textScaler: TextScaler.noScaling,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke * 2
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
          ),
        ),
        Text(
          text,
          textScaler: TextScaler.noScaling,
          style: style.copyWith(color: color),
        ),
      ],
    );
  }
}
