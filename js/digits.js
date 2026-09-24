// Stroke definitions for the digits 0–9.
// Each digit lives in a 100 × 140 box (y grows downward). A digit is a list of
// strokes, and each stroke is a polyline drawn in handwriting order.

const D2R = Math.PI / 180;
export const DIGIT_W = 100;
export const DIGIT_H = 140;
export const DIGIT_ADVANCE = 92;
export const STEP = 2;

export function arc(cx, cy, rx, ry, a0, a1) {
  const n = Math.max(8, Math.ceil(Math.abs(a1 - a0) / 3));
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const a = (a0 + ((a1 - a0) * i) / n) * D2R;
    pts.push([cx + rx * Math.cos(a), cy + ry * Math.sin(a)]);
  }
  return pts;
}

export function quad(p0, c, p1, n = 30) {
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const u = 1 - t;
    pts.push([
      u * u * p0[0] + 2 * u * t * c[0] + t * t * p1[0],
      u * u * p0[1] + 2 * u * t * c[1] + t * t * p1[1],
    ]);
  }
  return pts;
}

export const DIGITS = {
  0: [arc(50, 70, 34, 56, -90, -450)],
  1: [[[32, 34], [56, 12], [56, 128]]],
  2: [[...arc(50, 44, 31, 31, -165, 32), [18, 128], [84, 128]]],
  3: [[...arc(48, 40, 28, 26, -155, 90), ...arc(48, 97, 32, 31, -90, 155)]],
  4: [
    [[56, 12], [14, 92], [88, 92]],
    [[66, 12], [66, 128]],
  ],
  5: [
    [[28, 12], ...arc(50, 90, 36, 36, -140, 150)],
    [[28, 12], [80, 12]],
  ],
  6: [[...quad([72, 12], [22, 36], [16, 92]), ...arc(50, 92, 34, 34, 180, -180)]],
  7: [[[16, 14], [84, 14], [40, 128]]],
  8: [
    [
      ...arc(50, 38, 25, 25, -20, -270),
      ...arc(50, 96, 31, 31, -90, 270),
      ...arc(50, 38, 25, 25, 90, -20),
    ],
  ],
  9: [[...arc(48, 42, 30, 30, 0, -360), [76, 128]]],
};

// Turn a polyline into evenly spaced points so tracing progress is uniform.
export function resample(points, step = STEP) {
  const out = [points[0].slice()];
  let carry = 0;
  for (let i = 1; i < points.length; i++) {
    const [x0, y0] = points[i - 1];
    const [x1, y1] = points[i];
    const len = Math.hypot(x1 - x0, y1 - y0);
    if (len === 0) continue;
    let d = step - carry;
    while (d <= len) {
      const t = d / len;
      out.push([x0 + (x1 - x0) * t, y0 + (y1 - y0) * t]);
      d += step;
    }
    carry = len - (d - step);
  }
  const last = points[points.length - 1];
  const tail = out[out.length - 1];
  if (Math.hypot(last[0] - tail[0], last[1] - tail[1]) > 0.01) out.push(last.slice());
  return out;
}

// Lay out a whole number (e.g. 17) as one list of strokes in a shared box.
export function layoutNumber(n) {
  const chars = String(n).split('');
  const strokes = [];
  chars.forEach((ch, i) => {
    const dx = i * DIGIT_ADVANCE;
    for (const stroke of DIGITS[ch]) {
      strokes.push(resample(stroke.map(([x, y]) => [x + dx, y])));
    }
  });
  return {
    width: DIGIT_W + (chars.length - 1) * DIGIT_ADVANCE,
    height: DIGIT_H,
    strokes,
  };
}
