// Balloon pop: pop only the balloons showing the target number.
import { sfx, speak, sayNumber, WORDS } from './audio.js';
import { reward } from './fx.js';

const COLORS = ['#ff5a5f', '#ffb020', '#34c759', '#2f9bff', '#a259ff', '#ff6fb5'];
const GOAL = 5;

export class BalloonGame {
  constructor(root, { onWin }) {
    this.root = root;
    this.onWin = onWin;
    this.sky = root.querySelector('.sky');
    this.targetEl = root.querySelector('.balloon-target');
    this.meter = root.querySelector('.balloon-meter');
    root.querySelector('.balloon-say').onclick = () => this.announce();
    this.balloons = [];
    this.running = false;
    this.max = 10;
  }

  start() {
    this.running = true;
    this.newTarget();
    this.last = performance.now();
    this.spawnAt = 0;
    cancelAnimationFrame(this.raf);
    this.raf = requestAnimationFrame((t) => this.tick(t));
  }

  stop() {
    this.running = false;
    cancelAnimationFrame(this.raf);
    this.balloons.forEach((b) => b.el.remove());
    this.balloons = [];
  }

  newTarget() {
    let t;
    do t = Math.floor(Math.random() * (this.max + 1));
    while (t === this.target);
    this.target = t;
    this.popped = 0;
    this.targetEl.textContent = t;
    this.renderMeter();
    this.announce();
  }

  announce() {
    speak(`Pop the number ${WORDS[this.target]}!`);
  }

  renderMeter() {
    this.meter.innerHTML = Array.from({ length: GOAL }, (_, i) => `<span class="${i < this.popped ? 'on' : ''}">🎈</span>`).join('');
  }

  spawn() {
    const w = this.sky.clientWidth;
    const h = this.sky.clientHeight;
    const isTarget = Math.random() < 0.4;
    let v = this.target;
    if (!isTarget) while (v === this.target) v = Math.floor(Math.random() * (this.max + 1));
    const el = document.createElement('button');
    el.className = 'balloon';
    el.style.setProperty('--c', COLORS[Math.floor(Math.random() * COLORS.length)]);
    el.innerHTML = `<span>${v}</span>`;
    const size = 84;
    const b = { el, v, x: 8 + Math.random() * Math.max(0, w - size - 16), y: h + 10, vy: 45 + Math.random() * 45, phase: Math.random() * 6 };
    el.onpointerdown = (e) => {
      e.preventDefault();
      this.hit(b);
    };
    this.sky.appendChild(el);
    this.balloons.push(b);
  }

  hit(b) {
    if (b.gone) return;
    if (b.v !== this.target) {
      sfx.oops();
      b.el.classList.remove('wobble');
      void b.el.offsetWidth;
      b.el.classList.add('wobble');
      sayNumber(b.v);
      return;
    }
    b.gone = true;
    b.el.classList.add('popped');
    setTimeout(() => b.el.remove(), 300);
    sfx.pop();
    this.popped++;
    this.renderMeter();
    sayNumber(b.v);
    if (this.popped >= GOAL) {
      this.running = false;
      this.onWin?.();
      reward({
        title: 'Super popping!',
        stars: 3,
        onNext: () => {
          this.stop();
          this.start();
        },
      });
    }
  }

  tick(t) {
    const dt = Math.min(0.05, (t - this.last) / 1000);
    this.last = t;
    if (this.running) {
      this.spawnAt -= dt;
      if (this.spawnAt <= 0) {
        this.spawn();
        this.spawnAt = 0.9 + Math.random() * 0.6;
      }
    }
    for (const b of this.balloons) {
      if (b.gone) continue;
      b.y -= b.vy * dt;
      const sway = Math.sin(t / 700 + b.phase) * 10;
      b.el.style.transform = `translate(${b.x + sway}px, ${b.y}px)`;
      if (b.y < -140) {
        b.gone = true;
        b.el.remove();
      }
    }
    this.balloons = this.balloons.filter((b) => !b.gone || b.el.isConnected);
    this.raf = requestAnimationFrame((tt) => this.tick(tt));
  }
}

