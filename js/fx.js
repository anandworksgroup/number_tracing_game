// Confetti and the reward popup shared by all games.
import { sfx, speak, sayNumber } from './audio.js';

const canvas = document.getElementById('confetti');
const g = canvas.getContext('2d');
let bits = [];
let raf = 0;

export function confetti(count = 140) {
  const dpr = window.devicePixelRatio || 1;
  canvas.width = innerWidth * dpr;
  canvas.height = innerHeight * dpr;
  g.setTransform(dpr, 0, 0, dpr, 0, 0);
  for (let i = 0; i < count; i++) {
    bits.push({
      x: innerWidth / 2 + (Math.random() - 0.5) * 120,
      y: innerHeight * 0.45,
      vx: (Math.random() - 0.5) * 14,
      vy: -Math.random() * 14 - 4,
      r: Math.random() * Math.PI,
      vr: (Math.random() - 0.5) * 0.3,
      w: 6 + Math.random() * 6,
      h: 4 + Math.random() * 4,
      c: `hsl(${Math.random() * 360} 90% 60%)`,
    });
  }
  if (!raf) raf = requestAnimationFrame(tick);
}

function tick() {
  g.clearRect(0, 0, innerWidth, innerHeight);
  bits = bits.filter((b) => b.y < innerHeight + 30);
  for (const b of bits) {
    b.x += b.vx;
    b.y += b.vy;
    b.vy += 0.35;
    b.vx *= 0.99;
    b.r += b.vr;
    g.save();
    g.translate(b.x, b.y);
    g.rotate(b.r);
    g.fillStyle = b.c;
    g.fillRect(-b.w / 2, -b.h / 2, b.w, b.h);
    g.restore();
  }
  raf = bits.length ? requestAnimationFrame(tick) : 0;
}

const panel = document.getElementById('reward');
const titleEl = panel.querySelector('.reward-title');
const starsEl = panel.querySelector('.reward-stars');
const itemsEl = panel.querySelector('.reward-items');
const againBtn = panel.querySelector('[data-act="again"]');
const nextBtn = panel.querySelector('[data-act="next"]');
let timers = [];

export const EMOJIS = ['🍎', '⭐', '🐟', '🎈', '🍓', '🐥', '🌸', '🚗', '🍪', '🦋', '🐞', '🍩'];

// Show "Great job!" with stars; optionally count n objects in one by one.
export function reward({ title = 'Great job!', stars = 3, count = null, emoji = '🍎', onAgain, onNext }) {
  timers.forEach(clearTimeout);
  timers = [];
  titleEl.textContent = title;
  starsEl.innerHTML = [1, 2, 3].map((i) => `<span class="${i <= stars ? 'on' : ''}">★</span>`).join('');
  itemsEl.innerHTML = '';
  againBtn.hidden = !onAgain;
  againBtn.onclick = () => close(onAgain);
  nextBtn.onclick = () => close(onNext);
  panel.hidden = false;
  confetti();
  sfx.win();

  if (count === null) {
    speak(title);
    return;
  }
  if (count === 0) {
    itemsEl.innerHTML = '<div class="reward-zero">🧺<small>zero — nothing here!</small></div>';
    timers.push(setTimeout(() => speak('Zero! Nothing in the basket.'), 700));
    return;
  }
  speak(title);
  for (let i = 1; i <= count; i++) {
    timers.push(
      setTimeout(() => {
        const el = document.createElement('span');
        el.className = 'reward-item';
        el.innerHTML = `${emoji}<b>${i}</b>`;
        itemsEl.appendChild(el);
        sfx.tap();
        sayNumber(i);
      }, 900 + i * 700),
    );
  }
}

function close(cb) {
  timers.forEach(clearTimeout);
  panel.hidden = true;
  cb?.();
}

export function hideReward() {
  timers.forEach(clearTimeout);
  panel.hidden = true;
}
