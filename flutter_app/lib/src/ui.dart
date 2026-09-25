// Colours and small widgets shared by every screen.
import 'package:flutter/material.dart';

import 'audio.dart';

const ink = Color(0xFF3B2A7A);
const purple = Color(0xFF7C5CE6);
const skyTop = Color(0xFF8EE3FF);
const skyBottom = Color(0xFFC9F7D4);
const red = Color(0xFFFF5A5F);
const blue = Color(0xFF2F9BFF);
const orange = Color(0xFFFFB020);
const green = Color(0xFF34C759);
const gold = Color(0xFFFFC107);

const crayons = [
  Color(0xFFFF5A5F),
  Color(0xFFFF9F1C),
  Color(0xFFFFD23F),
  Color(0xFF34C759),
  Color(0xFF2F9BFF),
  Color(0xFFA259FF),
  Color(0xFFFF6FB5),
];

const crayonNames = ['Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Purple', 'Pink'];

const cardShadow = [BoxShadow(color: Color(0x2E3B2A7A), offset: Offset(0, 6))];

Color darker(Color c, [double amount = 0.3]) => Color.lerp(c, Colors.black, amount)!;

/// Sky gradient behind every screen, with safe-area padding.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [skyTop, skyBottom]),
      ),
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: child),
      ),
    );
  }
}

/// Pressable widget that sinks a little when touched.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.depth = 4, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final double depth;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                Audio.instance.play(Sfx.tap);
                widget.onTap!();
              },
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 80),
          offset: Offset(0, _down ? widget.depth / 100 : 0),
          child: widget.child,
        ),
      ),
    );
  }
}

/// White circular button holding an emoji or icon.
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.child, this.onTap, this.label, this.size = 52});
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: cardShadow),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: size * 0.44),
          child: child,
        ),
      ),
    );
  }
}

class Emoji extends StatelessWidget {
  const Emoji(this.text, {super.key, this.size});
  final String text;
  final double? size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: size, height: 1.1),
    textScaler: TextScaler.noScaling,
  );
}

/// Big coloured pill button with a 3D edge.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.color,
    required this.label,
    this.emoji,
    this.onTap,
    this.width = 360,
    this.fontSize = 32,
  });
  final Color color;
  final String label;
  final String? emoji;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 6,
      semanticLabel: label,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: width),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: fontSize * 0.35),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: darker(color), offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji != null) ...[Emoji(emoji!, size: fontSize * 1.15), const SizedBox(width: 14)],
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Color(0x26000000), offset: Offset(0, 2))],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Top bar: back button, title, optional trailing button.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.trailing});
  final Widget title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          RoundButton(
            label: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_rounded, color: ink, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink),
              child: FittedBox(fit: BoxFit.scaleDown, child: title),
            ),
          ),
          const SizedBox(width: 12),
          trailing ?? const SizedBox(width: 52),
        ],
      ),
    );
  }
}

/// Shakes its child sideways whenever [trigger] changes.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        final dx = t == 0 || t == 1 ? 0.0 : 8 * (1 - t) * (((t * 8).floor().isEven) ? -1 : 1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Springy scale-in, optionally delayed.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
      child: FadeTransition(opacity: _c, child: widget.child),
    );
  }
}
