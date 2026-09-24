// The tracing board: draws the number "tube", guide dots, arrows, the green
// start dot and the demo hand, and feeds finger movement into [TraceLogic].
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'digits.dart';
import 'trace_logic.dart';

const double _pad = 22;

/// Scale and offset that fit a number layout inside [size].
({double scale, Offset offset}) fitLayout(Size size, NumberLayout layout) {
  final s = min(size.width / (layout.width + _pad * 2), size.height / (layout.height + _pad * 2));
  return (scale: s, offset: Offset((size.width - layout.width * s) / 2, (size.height - layout.height * s) / 2));
}

class _Particle {
  _Particle(this.pos, this.vel, this.hue);
  Offset pos;
  Offset vel;
  final double hue;
  double life = 1;
}

class TraceBoard extends StatefulWidget {
  const TraceBoard({super.key, required this.logic, required this.color, this.demoKey = 0});

  final TraceLogic logic;
  final Color color;

  /// Change this value to play the demo hand again.
  final int demoKey;

  @override
  State<TraceBoard> createState() => _TraceBoardState();
}

class _TraceBoardState extends State<TraceBoard> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _rand = Random();
  final _particles = <_Particle>[];
  Duration _now = Duration.zero;
  Duration? _demoStart;
  bool _demoPending = true;
  int? _pointer;
  double _scale = 1;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didUpdateWidget(TraceBoard old) {
    super.didUpdateWidget(old);
    if (old.logic != widget.logic) _particles.clear();
    if (old.logic != widget.logic || old.demoKey != widget.demoKey) _demoPending = true;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    if (_demoPending) {
      _demoPending = false;
      _demoStart = widget.logic.done ? null : elapsed;
    }
    if (_demoStart != null && _demoFraction() > 1.35) _demoStart = null;
    for (final p in _particles) {
      p.pos += p.vel;
      p.vel += const Offset(0, 0.04);
      p.life -= 0.03;
    }
    _particles.removeWhere((p) => p.life <= 0);
    setState(() {});
  }

  double _demoFraction() {
    final len = widget.logic.stroke.length;
    final dur = max(1200, len * 9);
    return (_now - _demoStart!).inMicroseconds / 1000 / dur;
  }

  Offset _toLayout(Offset local) => (local - _offset) / _scale;

  void _sparkle(Offset at) {
    if (_rand.nextBool()) return;
    final a = _rand.nextDouble() * pi * 2;
    final v = 0.6 + _rand.nextDouble() * 1.4;
    _particles.add(_Particle(at, Offset(cos(a) * v, sin(a) * v - 0.5), _rand.nextDouble() * 360));
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _demoStart = null;
    final before = (widget.logic.strokeIndex, widget.logic.progress);
    widget.logic.down(_toLayout(e.localPosition), widget.color);
    _afterMove(before);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || !widget.logic.drawing) return;
    final before = (widget.logic.strokeIndex, widget.logic.progress);
    widget.logic.move(_toLayout(e.localPosition), widget.color);
    _afterMove(before);
  }

  void _afterMove((int, int) before) {
    final logic = widget.logic;
    if (!logic.done && logic.strokeIndex == before.$1 && logic.progress > before.$2) {
      _sparkle(logic.dot);
    }
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    widget.logic.up();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final fit = fitLayout(size, widget.logic.layout);
        _scale = fit.scale;
        _offset = fit.offset;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: CustomPaint(
            size: size,
            painter: _TracePainter(
              logic: widget.logic,
              color: widget.color,
              ms: _now.inMicroseconds / 1000,
              demo: _demoStart == null ? null : _demoFraction(),
              particles: _particles,
              scale: fit.scale,
              offset: fit.offset,
            ),
          ),
        );
      },
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.logic,
    required this.color,
    required this.ms,
    required this.demo,
    required this.particles,
    required this.scale,
    required this.offset,
  });

  final TraceLogic logic;
  final Color color;
  final double ms;
  final double? demo;
  final List<_Particle> particles;
  final double scale;
  final Offset offset;

  static Path _path(List<Offset> pts, [int from = 0, int? to]) {
    final end = to ?? pts.length - 1;
    final p = Path()..moveTo(pts[from].dx, pts[from].dy);
    for (var i = from + 1; i <= end; i++) {
      p.lineTo(pts[i].dx, pts[i].dy);
    }
    return p;
  }

  static Paint _line(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final strokes = logic.layout.strokes;

    // The "tube" the child traces inside.
    for (final pts in strokes) {
      canvas.drawPath(_path(pts), _line(const Color(0xFFC7B6FF), 36));
    }
    for (final pts in strokes) {
      canvas.drawPath(_path(pts), _line(Colors.white, 29));
    }

    // Dotted guide line for the parts still to trace.
    final dot = Paint()..color = const Color(0xFFB3A1EE);
    if (!logic.done) {
      for (var s = logic.strokeIndex; s < strokes.length; s++) {
        final pts = strokes[s];
        final from = s == logic.strokeIndex ? logic.progress : 0;
        for (var i = from; i < pts.length; i += 4) {
          canvas.drawCircle(pts[i], 2, dot);
        }
      }
    }

    // Finished strokes and the current partial stroke in crayon colour.
    for (final f in logic.finished) {
      canvas.drawPath(_path(f.points), _line(f.color, 23));
    }
    if (!logic.done && logic.progress > 0) {
      canvas.drawPath(_path(logic.stroke, 0, logic.progress), _line(color, 23));
    }

    if (!logic.done) {
      _arrows(canvas);
      _star(canvas, logic.stroke.last);
      _badges(canvas);
      _startDot(canvas);
      _demoHand(canvas);
    }

    for (final p in particles) {
      canvas.drawCircle(p.pos, 2.5, Paint()..color = HSLColor.fromAHSL(p.life.clamp(0, 1), p.hue, 0.9, 0.6).toColor());
    }
    canvas.restore();
  }

  void _arrows(Canvas canvas) {
    final pts = logic.stroke;
    final shift = (ms / 60 % 14).floor();
    final paint = Paint()..color = const Color(0x8C7C5CE6);
    for (var i = logic.progress + 12 + shift; i < pts.length - 6; i += 14) {
      final a = atan2(pts[i + 1].dy - pts[i - 1].dy, pts[i + 1].dx - pts[i - 1].dx);
      canvas.save();
      canvas.translate(pts[i].dx, pts[i].dy);
      canvas.rotate(a);
      canvas.drawPath(
        Path()
          ..moveTo(5, 0)
          ..lineTo(-3, -5)
          ..lineTo(-3, 5)
          ..close(),
        paint,
      );
      canvas.restore();
    }
  }

  void _star(Canvas canvas, Offset c) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final r = i.isEven ? 9.0 : 4.0;
      final p = c + Offset(cos(a) * r, sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, _line(Colors.white, 3));
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC83D));
  }

  void _badges(Canvas canvas) {
    final strokes = logic.layout.strokes;
    for (var i = logic.strokeIndex + 1; i < strokes.length; i++) {
      final c = strokes[i].first;
      canvas.drawCircle(c, 9, Paint()..color = const Color(0xFFFFB020));
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _startDot(Canvas canvas) {
    final c = logic.dot;
    final pulse = (sin(ms / 220) + 1) / 2;
    if (!logic.drawing) {
      canvas.drawCircle(
        c,
        13 + pulse * 7,
        Paint()..color = const Color(0xFF34C759).withValues(alpha: 0.35 - pulse * 0.25),
      );
    }
    canvas.drawCircle(c, 11, Paint()..color = const Color(0xFF34C759));
    canvas.drawCircle(c, 11, _line(Colors.white, 3));
  }

  void _demoHand(Canvas canvas) {
    final k = demo;
    if (k == null || logic.drawing) return;
    final pts = logic.stroke;
    final i = (max(0.0, k) * pts.length).floor().clamp(0, pts.length - 1);
    if (i > 1) canvas.drawPath(_path(pts, 0, i), _line(const Color(0x5934C759), 10));
    final tp = TextPainter(
      text: const TextSpan(text: '👆', style: TextStyle(fontSize: 30)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pts[i] + const Offset(-9, -2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
