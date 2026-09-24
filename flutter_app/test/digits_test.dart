import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:number_tracing_game/src/digits.dart';
import 'package:number_tracing_game/src/trace_logic.dart';

void main() {
  test('every digit 0–9 has strokes inside its box', () {
    for (var d = 0; d <= 9; d++) {
      final strokes = digits['$d']!;
      expect(strokes, isNotEmpty);
      for (final s in strokes) {
        for (final p in s) {
          expect(
            p.dx >= 0 && p.dx <= digitWidth && p.dy >= 0 && p.dy <= digitHeight,
            isTrue,
            reason: 'digit $d point $p',
          );
        }
      }
    }
  });

  test('resample produces evenly spaced points and keeps the end', () {
    final pts = resample(const [Offset(0, 0), Offset(10, 0), Offset(10, 10)], 2);
    for (var i = 1; i < pts.length; i++) {
      expect((pts[i] - pts[i - 1]).distance, lessThanOrEqualTo(2 + 1e-6));
    }
    expect(pts.last, const Offset(10, 10));
  });

  test('two-digit numbers lay out side by side', () {
    final ten = layoutNumber(10);
    expect(ten.strokes.length, digits['1']!.length + digits['0']!.length);
    expect(ten.width, greaterThan(layoutNumber(1).width));
    final maxX = ten.strokes.expand((s) => s).map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    expect(maxX, lessThanOrEqualTo(ten.width));
  });

  group('tracing', () {
    const color = Color(0xFFFF0000);

    // A slightly wobbly finger that moves every third sample.
    void traceAll(TraceLogic logic) {
      while (!logic.done) {
        final pts = logic.stroke;
        expect(logic.down(pts.first + const Offset(3, -2), color), isTrue);
        for (var i = 0; i < pts.length; i += 3) {
          logic.move(pts[i] + Offset(i.isEven ? 5 : -5, i % 3 == 0 ? 4 : -4), color);
        }
        logic.move(pts.last, color);
        logic.up();
      }
    }

    test('every number 0–20 can be traced cleanly', () {
      for (var n = 0; n <= 20; n++) {
        int? strays;
        final logic = TraceLogic(n)..onComplete = (s) => strays = s;
        traceAll(logic);
        expect(logic.done, isTrue, reason: 'number $n');
        expect(strays, 0, reason: 'number $n');
        expect(logic.finished.length, logic.layout.strokes.length);
      }
    });

    test('touching away from the green dot does not start tracing', () {
      var missed = false;
      final logic = TraceLogic(3)..onMiss = () => missed = true;
      expect(logic.down(const Offset(90, 130), color), isFalse);
      expect(missed, isTrue);
      expect(logic.drawing, isFalse);
    });

    test('scribbling off the path counts a stray and keeps progress', () {
      final logic = TraceLogic(7);
      final pts = logic.stroke;
      logic.down(pts.first, color);
      for (var i = 0; i < 20; i++) {
        logic.move(pts[i], color);
      }
      final kept = logic.progress;
      expect(kept, greaterThan(10));
      expect(logic.move(pts[20] + const Offset(0, 60), color), isFalse);
      expect(logic.strays, 1);
      expect(logic.drawing, isFalse);
      expect(logic.progress, kept);
    });

    test('jumping far ahead along the path is not allowed', () {
      final logic = TraceLogic(1);
      final pts = logic.stroke;
      logic.down(pts.first, color);
      logic.move(pts.last, color);
      expect(logic.done, isFalse);
    });

    test('stars reflect slips', () {
      expect(starsFor(0), 3);
      expect(starsFor(2), 2);
      expect(starsFor(3), 1);
    });
  });
}
