// Stroke definitions for the digits 0–9.
//
// Each digit lives in a 100 × 140 box (y grows downward). A digit is a list of
// strokes, and each stroke is a polyline drawn in handwriting order.
import 'dart:math';
import 'dart:ui';

const double digitWidth = 100;
const double digitHeight = 140;
const double digitAdvance = 92;
const double sampleStep = 2;

List<Offset> arc(double cx, double cy, double rx, double ry, double a0, double a1) {
  final n = max(8, ((a1 - a0).abs() / 3).ceil());
  return [
    for (var i = 0; i <= n; i++)
      Offset(cx + rx * cos((a0 + (a1 - a0) * i / n) * pi / 180), cy + ry * sin((a0 + (a1 - a0) * i / n) * pi / 180)),
  ];
}

List<Offset> quad(Offset p0, Offset c, Offset p1, [int n = 30]) {
  return [
    for (var i = 0; i <= n; i++)
      () {
        final t = i / n;
        final u = 1 - t;
        return p0 * (u * u) + c * (2 * u * t) + p1 * (t * t);
      }(),
  ];
}

const _o = Offset.new;

final Map<String, List<List<Offset>>> digits = {
  '0': [arc(50, 70, 34, 56, -90, -450)],
  '1': [
    [_o(32, 34), _o(56, 12), _o(56, 128)],
  ],
  '2': [
    [...arc(50, 44, 31, 31, -165, 32), _o(18, 128), _o(84, 128)],
  ],
  '3': [
    [...arc(48, 40, 28, 26, -155, 90), ...arc(48, 97, 32, 31, -90, 155)],
  ],
  '4': [
    [_o(56, 12), _o(14, 92), _o(88, 92)],
    [_o(66, 12), _o(66, 128)],
  ],
  '5': [
    [_o(28, 12), ...arc(50, 90, 36, 36, -140, 150)],
    [_o(28, 12), _o(80, 12)],
  ],
  '6': [
    [...quad(_o(72, 12), _o(22, 36), _o(16, 92)), ...arc(50, 92, 34, 34, 180, -180)],
  ],
  '7': [
    [_o(16, 14), _o(84, 14), _o(40, 128)],
  ],
  '8': [
    [...arc(50, 38, 25, 25, -20, -270), ...arc(50, 96, 31, 31, -90, 270), ...arc(50, 38, 25, 25, 90, -20)],
  ],
  '9': [
    [...arc(48, 42, 30, 30, 0, -360), _o(76, 128)],
  ],
};

/// Turns a polyline into evenly spaced points so tracing progress is uniform.
List<Offset> resample(List<Offset> points, [double step = sampleStep]) {
  final out = <Offset>[points.first];
  var carry = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final len = (b - a).distance;
    if (len == 0) continue;
    var d = step - carry;
    while (d <= len) {
      out.add(Offset.lerp(a, b, d / len)!);
      d += step;
    }
    carry = len - (d - step);
  }
  if ((points.last - out.last).distance > 0.01) out.add(points.last);
  return out;
}

class NumberLayout {
  const NumberLayout(this.width, this.height, this.strokes);
  final double width;
  final double height;
  final List<List<Offset>> strokes;
}

/// Lays out a whole number (e.g. 17) as one list of strokes in a shared box.
NumberLayout layoutNumber(int n) {
  final chars = '$n'.split('');
  final strokes = <List<Offset>>[];
  for (final (i, ch) in chars.indexed) {
    final dx = i * digitAdvance;
    for (final stroke in digits[ch]!) {
      strokes.add(resample([for (final p in stroke) p.translate(dx, 0)]));
    }
  }
  return NumberLayout(digitWidth + (chars.length - 1) * digitAdvance, digitHeight, strokes);
}
