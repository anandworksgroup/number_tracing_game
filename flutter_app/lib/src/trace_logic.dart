// Tracing rules, independent of any widget so they can be unit tested.
// All positions are in the number's layout units (see digits.dart).
import 'dart:math';
import 'dart:ui';

import 'digits.dart';

const double tolerance = 17; // how far the finger may drift from the path
const double startTolerance = 24; // how close the first touch must be to the dot
const int lookahead = 30; // samples we may jump ahead in one move

class FinishedStroke {
  const FinishedStroke(this.points, this.color);
  final List<Offset> points;
  final Color color;
}

class TraceLogic {
  TraceLogic(int n) : number = n, layout = layoutNumber(n);

  final int number;
  final NumberLayout layout;
  int strokeIndex = 0;
  int progress = 0;
  bool drawing = false;
  bool done = false;
  int strays = 0;
  final List<FinishedStroke> finished = [];

  // Hooks for sound, speech and visuals.
  void Function()? onMiss;
  void Function()? onStray;
  void Function(int index)? onAdvance;
  void Function(int strokeIndex)? onStrokeDone;
  void Function(int strays)? onComplete;

  List<Offset> get stroke => layout.strokes[strokeIndex];
  Offset get dot => stroke[progress];

  /// Finger touches down. Returns true if tracing started.
  bool down(Offset p, Color color) {
    if (done) return false;
    if ((p - dot).distance <= startTolerance) {
      drawing = true;
      move(p, color);
      return true;
    }
    onMiss?.call();
    return false;
  }

  /// Finger moves. Returns false if it strayed off the path.
  bool move(Offset p, Color color) {
    if (!drawing || done) return false;
    final pts = stroke;
    final hi = min(pts.length - 1, progress + lookahead);
    var best = -1;
    var bestD = double.infinity;
    for (var i = max(0, progress - 4); i <= hi; i++) {
      final d = (pts[i] - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD > tolerance * 1.8) {
      drawing = false;
      strays++;
      onStray?.call();
      return false;
    }
    if (bestD <= tolerance && best > progress) {
      progress = best;
      onAdvance?.call(best);
    }
    if (progress >= pts.length - 3) _completeStroke(color);
    return true;
  }

  void up() => drawing = false;

  void _completeStroke(Color color) {
    finished.add(FinishedStroke(stroke, color));
    drawing = false;
    strokeIndex++;
    progress = 0;
    if (strokeIndex >= layout.strokes.length) {
      strokeIndex = layout.strokes.length - 1;
      done = true;
      onComplete?.call(strays);
    } else {
      onStrokeDone?.call(strokeIndex);
    }
  }
}

/// 3 stars for a clean trace, fewer for more slips.
int starsFor(int strays) => strays == 0 ? 3 : (strays <= 2 ? 2 : 1);
