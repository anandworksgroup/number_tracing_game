import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DIGITS, DIGIT_W, DIGIT_H, STEP, layoutNumber, resample } from '../js/digits.js';

test('every digit 0–9 has strokes inside its box', () => {
  for (let d = 0; d <= 9; d++) {
    const strokes = DIGITS[d];
    assert.ok(strokes.length >= 1, `digit ${d}`);
    for (const s of strokes) {
      for (const [x, y] of s) {
        assert.ok(x >= 0 && x <= DIGIT_W && y >= 0 && y <= DIGIT_H, `digit ${d} point ${x},${y}`);
      }
    }
  }
});

test('resample produces evenly spaced points', () => {
  const pts = resample([[0, 0], [10, 0], [10, 10]], 2);
  for (let i = 1; i < pts.length - 1; i++) {
    const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
    assert.ok(d <= STEP + 1e-6, `gap ${d}`);
  }
  assert.deepEqual(pts.at(-1), [10, 10]);
});

test('resampled strokes have no gaps a finger could jump', () => {
  for (let n = 0; n <= 20; n++) {
    for (const s of layoutNumber(n).strokes) {
      for (let i = 1; i < s.length; i++) {
        const d = Math.hypot(s[i][0] - s[i - 1][0], s[i][1] - s[i - 1][1]);
        assert.ok(d <= STEP + 0.01, `number ${n} gap ${d}`);
      }
    }
  }
});

test('two-digit numbers lay out side by side', () => {
  const one = layoutNumber(1);
  const ten = layoutNumber(10);
  assert.equal(ten.strokes.length, one.strokes.length + DIGITS[0].length);
  assert.ok(ten.width > one.width);
  const maxX = Math.max(...ten.strokes.flat().map((p) => p[0]));
  assert.ok(maxX <= ten.width);
});
