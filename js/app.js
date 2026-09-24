import { Tracer } from './trace.js';
import { CountGame } from './count.js';
import { BalloonGame } from './balloons.js';
import { settings, sfx, speak, sayNumber, WORDS } from './audio.js';
import { reward, hideReward, EMOJIS } from './fx.js';

const MAX = 20;
const STORE_KEY = 'trace123';
const CRAYONS = ['#ff5a5f', '#ff9f1c', '#ffd23f', '#34c759', '#2f9bff', '#a259ff', '#ff6fb5'];

// ---------- persisted progress ----------
const state = load();
function load() {
  try {
    return { stars: {}, trophies: 0, sound: true, voice: true, ...JSON.parse(localStorage.getItem(STORE_KEY) || '{}') };
  } catch {
    return { stars: {}, trophies: 0, sound: true, voice: true };
  }
}
function save() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state));
  } catch {}
}
settings.sound = state.sound;
settings.voice = state.voice;

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

// ---------- navigation ----------
let current = 'home';
let rewardTimer = 0;
function show(name) {
  clearTimeout(rewardTimer);
  hideReward();
  if (current === 'trace') tracer.stop();
  if (current === 'pop') balloons.stop();
  $$('.screen').forEach((s) => s.classList.toggle('active', s.id === name));
  current = name;
  if (name === 'home') renderHome();
  if (name === 'pick') renderPicker();
  if (name === 'trace') tracer.start();
  if (name === 'count') counter.start();
  if (name === 'pop') balloons.start();
}
document.addEventListener('click', (e) => {
  const go = e.target.closest('[data-go]');
  if (go) {
    sfx.tap();
    show(go.dataset.go);
  }
});

// ---------- home ----------
function renderHome() {
  const total = Object.values(state.stars).reduce((a, b) => a + b, 0);
  $('#home-stars').textContent = total + state.trophies;
  $('#toggle-sound').classList.toggle('off', !state.sound);
  $('#toggle-voice').classList.toggle('off', !state.voice);
}
$('#toggle-sound').onclick = () => {
  state.sound = settings.sound = !state.sound;
  save();
  renderHome();
  sfx.tap();
};
$('#toggle-voice').onclick = () => {
  state.voice = settings.voice = !state.voice;
  save();
  renderHome();
  speak('Hello!');
};
$('#reset').onclick = () => {
  if (!confirm('Reset all stars?')) return;
  state.stars = {};
  state.trophies = 0;
  save();
  renderHome();
};

// ---------- number picker ----------
function renderPicker() {
  const grid = $('#pick-grid');
  grid.innerHTML = '';
  for (let n = 0; n <= MAX; n++) {
    const s = state.stars[n] || 0;
    const b = document.createElement('button');
    b.className = 'tile' + (s ? ' done' : '');
    b.style.setProperty('--c', CRAYONS[n % CRAYONS.length]);
    b.innerHTML = `<span class="tile-n">${n}</span><span class="tile-stars">${'★'.repeat(s)}${'☆'.repeat(3 - s)}</span>`;
    b.onclick = () => openTrace(n);
    grid.appendChild(b);
  }
}

// ---------- tracing ----------
const traceScreen = $('#trace');
const tracer = new Tracer($('#trace-canvas'), {
  onComplete: (strays) => {
    const stars = strays === 0 ? 3 : strays <= 2 ? 2 : 1;
    state.stars[traceN] = Math.max(state.stars[traceN] || 0, stars);
    save();
    rewardTimer = setTimeout(() => {
      reward({
        title: `${cap(WORDS[traceN])}!`,
        stars,
        count: traceN,
        emoji: EMOJIS[traceN % EMOJIS.length],
        onAgain: () => openTrace(traceN),
        onNext: () => openTrace(traceN >= MAX ? 0 : traceN + 1),
      });
    }, 350);
  },
  onStray: () => shake(),
  onMiss: () => {
    tracer.showDemo();
    speak('Start at the green dot');
  },
});

let traceN = 0;
function openTrace(n) {
  traceN = n;
  if (current !== 'trace') show('trace');
  clearTimeout(rewardTimer);
  hideReward();
  $('#trace-num').textContent = n;
  $('#trace-word').textContent = WORDS[n];
  tracer.load(n);
  sayNumber(n);
}
$('#trace-prev').onclick = () => openTrace(traceN <= 0 ? MAX : traceN - 1);
$('#trace-next').onclick = () => openTrace(traceN >= MAX ? 0 : traceN + 1);
$('#trace-say').onclick = () => sayNumber(traceN);
$('#trace-help').onclick = () => tracer.showDemo();
$('#trace-clear').onclick = () => openTrace(traceN);

const palette = $('#palette');
CRAYONS.forEach((c, i) => {
  const b = document.createElement('button');
  b.className = 'crayon' + (i === 0 ? ' active' : '');
  b.style.setProperty('--c', c);
  b.setAttribute('aria-label', `colour ${i + 1}`);
  b.onclick = () => {
    tracer.color = c;
    $$('.crayon', palette).forEach((x) => x.classList.toggle('active', x === b));
    sfx.tap();
  };
  palette.appendChild(b);
});

function shake() {
  traceScreen.classList.remove('shake');
  void traceScreen.offsetWidth;
  traceScreen.classList.add('shake');
}
const cap = (s) => s[0].toUpperCase() + s.slice(1);

// ---------- mini games ----------
const trophy = () => {
  state.trophies++;
  save();
};
const counter = new CountGame($('#count'), { onWin: trophy });
const balloons = new BalloonGame($('#pop'), { onWin: trophy });

// ---------- boot ----------
renderHome();
if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
window.__app = { openTrace, tracer, counter, show, state };
