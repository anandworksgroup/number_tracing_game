// Guided tracing: the child drags the green dot along each stroke in order.
import { layoutNumber } from './digits.js';
import { sfx } from './audio.js';

const TOL = 17; // how far (layout units) the finger may drift from the path
const START_TOL = 24; // how close the first touch must be to the green dot
const LOOKAHEAD = 30; // samples we may jump ahead in one move
const PAD = 22;

export class Tracer {
  constructor(canvas, handlers = {}) {
    this.canvas = canvas;
    this.g = canvas.getContext('2d');
    this.h = handlers;
    this.color = '#ff5a5f';
    this.particles = [];
    this.running = false;
    this.bind();
    new ResizeObserver(() => this.resize()).observe(canvas);
  }

  load(n) {
    this.n = n;
    this.layout = layoutNumber(n);
    this.strokeIdx = 0;
    this.progress = 0;
    this.done = false;
    this.drawing = false;
    this.strays = 0;
    this.finished = []; // { points, color } for completed strokes
    this.resize();
    this.showDemo();
  }

  showDemo() {
    this.demo = this.done ? null : { t0: performance.now() };
  }

  start() {
    if (this.running) return;
    this.running = true;
    const loop = (t) => {
      if (!this.running) return;
      this.draw(t);
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  stop() {
    this.running = false;
  }

  resize() {
    const r = this.canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = Math.max(1, Math.round(r.width * dpr));
    this.canvas.height = Math.max(1, Math.round(r.height * dpr));
    this.cw = r.width;
    this.ch = r.height;
    this.dpr = dpr;
    if (!this.layout) return;
    const { width, height } = this.layout;
    this.s = Math.min(r.width / (width + PAD * 2), r.height / (height + PAD * 2));
    this.ox = (r.width - width * this.s) / 2;
    this.oy = (r.height - height * this.s) / 2;
  }

  get stroke() {
    return this.layout.strokes[this.strokeIdx];
  }

  toLayout(e) {
    const r = this.canvas.getBoundingClientRect();
    return [(e.clientX - r.left - this.ox) / this.s, (e.clientY - r.top - this.oy) / this.s];
  }

  bind() {
    const c = this.canvas;
    c.addEventListener('pointerdown', (e) => {
      if (this.done || !this.layout) return;
      e.preventDefault();
      c.setPointerCapture?.(e.pointerId);
      this.demo = null;
      const [x, y] = this.toLayout(e);
      const [px, py] = this.stroke[this.progress];
      if (Math.hypot(x - px, y - py) <= START_TOL) {
        this.drawing = true;
        this.advance(x, y);
      } else {
        this.h.onMiss?.();
      }
    });
    c.addEventListener('pointermove', (e) => {
      if (!this.drawing) return;
      e.preventDefault();
      const events = e.getCoalescedEvents ? e.getCoalescedEvents() : [e];
      for (const ev of events.length ? events : [e]) {
        const [x, y] = this.toLayout(ev);
        if (!this.advance(x, y)) break;
      }
    });
    const end = () => {
      this.drawing = false;
    };
    c.addEventListener('pointerup', end);
    c.addEventListener('pointercancel', end);
  }

  // Move progress forward to the nearest path sample near (x, y).
  // Returns false if the finger strayed off the path.
  advance(x, y) {
    const pts = this.stroke;
    const hi = Math.min(pts.length - 1, this.progress + LOOKAHEAD);
    let best = -1;
    let bestD = Infinity;
    for (let i = Math.max(0, this.progress - 4); i <= hi; i++) {
      const d = Math.hypot(pts[i][0] - x, pts[i][1] - y);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD > TOL * 1.8) {
      this.drawing = false;
      this.strays++;
      sfx.oops();
      this.h.onStray?.();
      return false;
    }
    if (bestD <= TOL && best > this.progress) {
      const before = this.progress;
      this.progress = best;
      if (Math.floor(best / 8) !== Math.floor(before / 8)) sfx.tick(best / 8);
      this.sparkle(pts[best]);
    }
    if (this.progress >= pts.length - 3) this.completeStroke();
    return true;
  }

  completeStroke() {
    this.finished.push({ points: this.stroke, color: this.color });
    this.drawing = false;
    this.strokeIdx++;
    this.progress = 0;
    if (this.strokeIdx >= this.layout.strokes.length) {
      this.done = true;
      this.h.onComplete?.(this.strays);
    } else {
      sfx.ding();
      this.h.onStroke?.(this.strokeIdx);
      this.demo = { t0: performance.now() };
    }
  }

  sparkle([x, y]) {
    if (Math.random() > 0.5) return;
    const a = Math.random() * Math.PI * 2;
    const v = 0.6 + Math.random() * 1.4;
    this.particles.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 0.5, life: 1, hue: Math.random() * 360 });
  }

  // ---------- rendering ----------

  path(g, pts, from = 0, to = pts.length - 1) {
    g.beginPath();
    g.moveTo(pts[from][0], pts[from][1]);
    for (let i = from + 1; i <= to; i++) g.lineTo(pts[i][0], pts[i][1]);
  }

  draw(t) {
    const g = this.g;
    g.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    g.clearRect(0, 0, this.cw, this.ch);
    if (!this.layout) return;
    g.save();
    g.translate(this.ox, this.oy);
    g.scale(this.s, this.s);
    g.lineCap = 'round';
    g.lineJoin = 'round';

    const strokes = this.layout.strokes;
    // The "tube" the child traces inside.
    for (const pts of strokes) {
      this.path(g, pts);
      g.strokeStyle = '#c7b6ff';
      g.lineWidth = 36;
      g.stroke();
    }
    for (const pts of strokes) {
      this.path(g, pts);
      g.strokeStyle = '#ffffff';
      g.lineWidth = 29;
      g.stroke();
    }
    // Dotted guide line.
    g.setLineDash([0.1, 7]);
    g.lineWidth = 4;
    g.strokeStyle = '#b3a1ee';
    for (let i = this.strokeIdx; i < strokes.length; i++) {
      this.path(g, strokes[i], i === this.strokeIdx ? this.progress : 0);
      g.stroke();
    }
    g.setLineDash([]);

    // Finished strokes and current partial stroke in crayon colour.
    g.lineWidth = 23;
    for (const f of this.finished) {
      this.path(g, f.points);
      g.strokeStyle = f.color;
      g.stroke();
    }
    if (!this.done && this.progress > 0) {
      this.path(g, this.stroke, 0, this.progress);
      g.strokeStyle = this.color;
      g.stroke();
    }

    if (!this.done) {
      this.drawArrows(g, t);
      this.drawBadges(g);
      this.drawStartDot(g, t);
      this.drawDemo(g, t);
    }
    this.drawParticles(g);
    g.restore();
  }

  drawArrows(g, t) {
    const pts = this.stroke;
    const shift = Math.floor((t / 60) % 14);
    g.fillStyle = 'rgba(124, 92, 230, 0.55)';
    for (let i = this.progress + 12 + shift; i < pts.length - 6; i += 14) {
      const [x0, y0] = pts[i - 1];
      const [x1, y1] = pts[i + 1];
      const a = Math.atan2(y1 - y0, x1 - x0);
      g.save();
      g.translate(pts[i][0], pts[i][1]);
      g.rotate(a);
      g.beginPath();
      g.moveTo(5, 0);
      g.lineTo(-3, -5);
      g.lineTo(-3, 5);
      g.closePath();
      g.fill();
      g.restore();
    }
    // Finish star at the end of the current stroke.
    const [ex, ey] = pts[pts.length - 1];
    g.font = '18px system-ui, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText('⭐', ex, ey);
  }

  drawBadges(g) {
    const strokes = this.layout.strokes;
    g.font = 'bold 11px system-ui, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    for (let i = this.strokeIdx + 1; i < strokes.length; i++) {
      const [x, y] = strokes[i][0];
      g.fillStyle = '#ffb020';
      g.beginPath();
      g.arc(x, y, 9, 0, Math.PI * 2);
      g.fill();
      g.fillStyle = '#fff';
      g.fillText(String(i + 1), x, y + 0.5);
    }
  }

  drawStartDot(g, t) {
    const [x, y] = this.stroke[this.progress];
    const pulse = (Math.sin(t / 220) + 1) / 2;
    if (!this.drawing) {
      g.beginPath();
      g.arc(x, y, 13 + pulse * 7, 0, Math.PI * 2);
      g.fillStyle = `rgba(52, 199, 89, ${0.35 - pulse * 0.25})`;
      g.fill();
    }
    g.beginPath();
    g.arc(x, y, 11, 0, Math.PI * 2);
    g.fillStyle = '#34c759';
    g.fill();
    g.lineWidth = 3;
    g.strokeStyle = '#fff';
    g.stroke();
  }

  drawDemo(g, t) {
    if (!this.demo || this.drawing) return;
    const pts = this.stroke;
    const dur = Math.max(1200, pts.length * 9);
    const k = (t - this.demo.t0) / dur;
    if (k > 1.35) {
      this.demo = null;
      return;
    }
    const i = Math.min(pts.length - 1, Math.floor(Math.max(0, k) * pts.length));
    if (i > 1) {
      this.path(g, pts, 0, i);
      g.strokeStyle = 'rgba(52, 199, 89, 0.35)';
      g.lineWidth = 10;
      g.stroke();
    }
    const [x, y] = pts[i];
    g.font = '30px system-ui, sans-serif';
    g.textAlign = 'left';
    g.textBaseline = 'top';
    g.fillText('👆', x - 9, y - 2);
  }

  drawParticles(g) {
    this.particles = this.particles.filter((p) => p.life > 0);
    for (const p of this.particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.04;
      p.life -= 0.03;
      g.globalAlpha = Math.max(0, p.life);
      g.fillStyle = `hsl(${p.hue} 90% 60%)`;
      g.beginPath();
      g.arc(p.x, p.y, 2.5, 0, Math.PI * 2);
      g.fill();
    }
    g.globalAlpha = 1;
  }
}
