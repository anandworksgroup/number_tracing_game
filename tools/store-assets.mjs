// Generates the app icons and the Google Play store graphics.
//
//   npm run store-assets
//
// Outputs:
//   icons/icon.svg, icons/icon-192.png, icons/icon-512.png   app icons (rounded)
//   icons/maskable-512.png                                   Android adaptive icon (full bleed)
//   store/icon-512.png                                       Play Store hi-res icon
//   store/feature-graphic.jpg                                1024 × 500 feature graphic
//   store/phone/*.jpg                                        1080 × 1920 phone screenshots
//   store/tablet-7/*.jpg, store/tablet-10/*.jpg              7" and 10" tablet screenshots
//
// Screenshots are taken from the real app, driven by Playwright.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { DIGITS, DIGIT_ADVANCE } from '../js/digits.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const FONT_DIR = path.join(ROOT, 'node_modules/@fontsource/baloo-2/files');
const STORE = path.join(ROOT, 'store');
const ICONS = path.join(ROOT, 'icons');

// ---------- local static server ----------

const TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webmanifest': 'application/manifest+json',
  '.woff2': 'font/woff2',
};

function serve() {
  const server = http.createServer(async (req, res) => {
    const p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    const [dir, rel] = p.startsWith('/__fonts/') ? [FONT_DIR, p.slice(9)] : [ROOT, p === '/' ? 'index.html' : p];
    const file = path.join(dir, rel);
    try {
      if (!file.startsWith(dir)) throw new Error('outside root');
      const data = await fs.readFile(file);
      res.writeHead(200, {
        'content-type': TYPES[path.extname(file)] || 'application/octet-stream',
        'access-control-allow-origin': '*',
      });
      res.end(data);
    } catch {
      res.writeHead(404);
      res.end();
    }
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

// Serve the app's Google Font locally so renders don't depend on the network.
const fontCss = (base) =>
  [500, 700, 800]
    .map(
      (w) =>
        `@font-face{font-family:'Baloo 2';font-style:normal;font-weight:${w};font-display:block;` +
        `src:url(${base}/__fonts/baloo-2-latin-${w}-normal.woff2) format('woff2')}`,
    )
    .join('\n');

// ---------- icon ----------

function digitPath(ch, dx) {
  return DIGITS[ch]
    .map((stroke) => 'M' + stroke.map(([x, y]) => `${(x + dx).toFixed(1)} ${y.toFixed(1)}`).join('L'))
    .join('');
}

function starPoints(cx, cy, R, r) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rad = i % 2 ? r : R;
    pts.push(`${(cx + rad * Math.cos(a)).toFixed(1)},${(cy + rad * Math.sin(a)).toFixed(1)}`);
  }
  return pts.join(' ');
}

// "123" drawn with the same stroke paths the child traces in the app.
function iconSvg({ rounded }) {
  const s = 1.08;
  const w = 100 + 2 * DIGIT_ADVANCE;
  const h = 140;
  const tx = 256 - (w * s) / 2;
  const ty = 266 - (h * s) / 2;
  const colors = ['#ff5a5f', '#ffd23f', '#34c759'];
  const paths = ['1', '2', '3'].map((ch, i) => ({ d: digitPath(ch, i * DIGIT_ADVANCE), c: colors[i] }));
  const layer = (attrs) => paths.map((p) => `<path d="${p.d}" ${attrs(p)}/>`).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.4" y2="1">
      <stop offset="0" stop-color="#a386ff"/>
      <stop offset="1" stop-color="#5a3bc4"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512"${rounded ? ' rx="112"' : ''} fill="url(#bg)"/>
  <circle cx="256" cy="266" r="200" fill="#ffffff" opacity="0.1"/>
  <g transform="translate(${tx.toFixed(1)} ${ty.toFixed(1)}) scale(${s})" fill="none" stroke-linecap="round" stroke-linejoin="round">
    <g transform="translate(0 6)">${layer(() => 'stroke="#2a1b66" stroke-opacity="0.35" stroke-width="40"')}</g>
    ${layer(() => 'stroke="#ffffff" stroke-width="40"')}
    ${layer((p) => `stroke="${p.c}" stroke-width="27"`)}
  </g>
  <polygon points="${starPoints(392, 126, 40, 17)}" fill="#ffd23f" stroke="#ffffff" stroke-width="7" stroke-linejoin="round"/>
  <circle cx="128" cy="400" r="9" fill="#ffffff" opacity="0.8"/>
  <circle cx="408" cy="392" r="6" fill="#ffffff" opacity="0.7"/>
  <circle cx="112" cy="136" r="6" fill="#ffffff" opacity="0.7"/>
</svg>
`;
}

async function renderSvg(browser, svg, size, file, { transparent }) {
  const page = await browser.newPage({ viewport: { width: size, height: size } });
  await page.setContent(
    `<style>html,body{margin:0;background:transparent}svg{display:block}</style>` +
      svg.replace('<svg ', `<svg width="${size}" height="${size}" `),
  );
  await page.screenshot({ path: file, omitBackground: transparent });
  await page.close();
}

// ---------- app screenshots ----------

const SEEDED_RANDOM = `(() => {
  let a = 20240924;
  Math.random = () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
})();`;

const PROGRESS = {
  stars: { 0: 3, 1: 3, 2: 3, 3: 2, 4: 3, 5: 1, 6: 2, 7: 3, 8: 1 },
  trophies: 4,
  sound: true,
  voice: true,
};

const strokesOnScreen = (page) =>
  page.evaluate(() => {
    const t = window.__app.tracer;
    const r = t.canvas.getBoundingClientRect();
    return t.layout.strokes.map((pts) => pts.map(([x, y]) => [r.left + t.ox + x * t.s, r.top + t.oy + y * t.s]));
  });

// Drag the mouse along a stroke; `upto` < 1 stops part way with the finger still down.
async function drag(page, pts, upto = 1) {
  const end = Math.floor((pts.length - 1) * upto);
  await page.mouse.move(...pts[0]);
  await page.mouse.down();
  for (let i = 0; i <= end; i += 3) await page.mouse.move(...pts[i]);
  await page.mouse.move(...pts[end]);
  if (upto >= 1) await page.mouse.up();
}

const openTrace = (page, n) => page.evaluate((n) => window.__app.openTrace(n), n);
const show = (page, name) => page.evaluate((name) => window.__app.show(name), name);

const SCENES = {
  async home(page) {
    await page.waitForTimeout(700);
  },
  async trace(page) {
    await openTrace(page, 2);
    await page.waitForTimeout(300);
    const [stroke] = await strokesOnScreen(page);
    await drag(page, stroke, 0.62);
    await page.waitForTimeout(200);
  },
  async guide(page) {
    await openTrace(page, 8);
    await page.waitForTimeout(300);
    // Freeze the demo hand part way along the stroke.
    await page.evaluate(() => {
      const t = window.__app.tracer;
      t.stop();
      const now = performance.now();
      const dur = Math.max(1200, t.stroke.length * 9);
      t.demo = { t0: now - dur * 0.42 };
      t.draw(now);
    });
  },
  async reward(page) {
    await openTrace(page, 4);
    await page.waitForTimeout(300);
    for (const stroke of await strokesOnScreen(page)) await drag(page, stroke);
    await page.waitForTimeout(4900); // counting animation
  },
  async count(page) {
    await show(page, 'count');
    // Re-roll until there are enough objects to make a busy picture.
    while ((await page.$$('.count-obj')).length < 6) await page.evaluate(() => window.__app.counter.start());
    await page.waitForTimeout(900);
    const objs = await page.$$('.count-obj');
    for (const o of objs.slice(0, Math.ceil(objs.length * 0.6))) await o.click();
    await page.waitForTimeout(500);
  },
  async pop(page) {
    await show(page, 'pop');
    await page.waitForTimeout(5200);
  },
  async pick(page) {
    await show(page, 'pick');
    await page.waitForTimeout(600);
  },
};

async function captureScene(browser, base, name, { vw, vh, dpr }) {
  const ctx = await browser.newContext({
    viewport: { width: vw, height: vh },
    deviceScaleFactor: dpr,
    isMobile: true,
    hasTouch: true,
    serviceWorkers: 'block',
  });
  await ctx.route('https://fonts.googleapis.com/**', (r) => r.fulfill({ contentType: 'text/css', body: fontCss(base) }));
  await ctx.route('https://fonts.gstatic.com/**', (r) => r.abort());
  await ctx.addInitScript(SEEDED_RANDOM);
  await ctx.addInitScript((p) => localStorage.setItem('trace123', JSON.stringify(p)), PROGRESS);
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(base + '/');
  await page.evaluate(() => Promise.all([500, 700, 800].map((w) => document.fonts.load(`${w} 20px "Baloo 2"`))));
  await SCENES[name](page);
  const png = await page.screenshot();
  await ctx.close();
  if (errors.length) throw new Error(`${name}: ${errors.join('; ')}`);
  return png;
}

// ---------- marketing layouts ----------

const dataUrl = (png) => `data:image/png;base64,${png.toString('base64')}`;

const BG_DIGITS = `
  <span style="left:-4%;top:30%;font-size:48vw;transform:rotate(-12deg)">1</span>
  <span style="right:-8%;top:52%;font-size:52vw;transform:rotate(10deg)">2</span>
  <span style="left:6%;bottom:-12%;font-size:40vw;transform:rotate(6deg)">3</span>`;

const BASE_CSS = (base) => `${fontCss(base)}
  *{box-sizing:border-box}
  html,body{margin:0;width:100%;height:100%;overflow:hidden}
  body{font-family:'Baloo 2',sans-serif;position:relative}
  .deco{position:absolute;inset:0;overflow:hidden}
  .deco span{position:absolute;font-weight:800;line-height:1;color:#fff;opacity:.12}
  .frame{background:#1d1640;box-shadow:0 30px 60px rgba(30,15,80,.35)}
  .frame img{display:block;width:100%;height:100%}`;

function slideHtml({ W, H, title, sub, c1, c2, shot, base }) {
  const headH = H * 0.215;
  const availH = H - headH - H * 0.045;
  const sw = Math.min(W * 0.8, availH / (H / W + 0.07));
  const sh = (sw * H) / W;
  const pad = sw * 0.035;
  return `<!doctype html><html><head><style>${BASE_CSS(base)}
  body{background:linear-gradient(160deg,${c1},${c2})}
  header{position:absolute;left:6%;right:6%;top:0;height:${headH}px;display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center;color:#fff}
  h1{margin:0;text-wrap:balance;font-size:${W * 0.074}px;line-height:1.02;font-weight:800;text-shadow:0 ${W * 0.005}px 0 rgba(0,0,0,.15)}
  p{margin:${W * 0.012}px 0 0;text-wrap:balance;font-size:${W * 0.037}px;line-height:1.2;font-weight:700;opacity:.95}
  .frame{position:absolute;left:${(W - sw) / 2 - pad}px;top:${headH}px;width:${sw + 2 * pad}px;height:${sh + 2 * pad}px;padding:${pad}px;border-radius:${sw * 0.09}px}
  .frame img{border-radius:${sw * 0.06}px}
  </style></head><body>
  <div class="deco">${BG_DIGITS}</div>
  <header><h1>${title}</h1><p>${sub}</p></header>
  <div class="frame"><img src="${dataUrl(shot)}"></div>
  </body></html>`;
}

function featureHtml({ shot, base }) {
  const balloon = (x, y, n, c, s = 1) =>
    `<div class="balloon" style="left:${x}px;top:${y}px;--c:${c};transform:scale(${s})"><b>${n}</b></div>`;
  return `<!doctype html><html><head><style>${BASE_CSS(base)}
  body{background:linear-gradient(180deg,#8ee3ff,#c9f7d4);color:#3b2a7a}
  .title{position:absolute;left:56px;top:40px;width:560px;text-align:center}
  .logo{font-size:190px;line-height:.95;font-weight:800;letter-spacing:4px}
  .logo span{display:inline-block;-webkit-text-stroke:10px #fff;paint-order:stroke fill}
  .logo span:nth-child(1){color:#ff5a5f;transform:rotate(-6deg)}
  .logo span:nth-child(2){color:#34c759;transform:translateY(-10px)}
  .logo span:nth-child(3){color:#2f9bff;transform:rotate(6deg)}
  .name{font-size:68px;font-weight:800;line-height:1;margin-top:6px}
  .tag{display:inline-block;margin-top:18px;padding:6px 26px;border-radius:99px;background:#fff;font-size:30px;font-weight:700;box-shadow:0 6px 0 rgba(59,42,122,.15)}
  .frame{position:absolute;left:676px;top:52px;width:270px;height:500px;padding:10px;border-radius:34px;transform:rotate(7deg)}
  .frame img{border-radius:24px;object-fit:cover;object-position:top}
  .balloon{position:absolute;width:74px;height:88px;border-radius:50% 50% 48% 48%/55% 55% 45% 45%;
    background:radial-gradient(circle at 32% 28%,rgba(255,255,255,.6) 0 12%,transparent 13%),var(--c);display:grid;place-items:center}
  .balloon::after{content:'';position:absolute;left:36px;top:86px;width:2px;height:34px;background:rgba(0,0,0,.25)}
  .balloon b{color:#fff;font-size:40px;font-weight:800;text-shadow:0 2px 0 rgba(0,0,0,.2)}
  </style></head><body>
  ${balloon(612, 300, 5, '#ffb020', 0.9)}${balloon(952, 60, 7, '#a259ff', 0.85)}${balloon(930, 330, 4, '#ff6fb5')}
  <div class="frame"><img src="${dataUrl(shot)}"></div>
  <div class="title">
    <div class="logo"><span>1</span><span>2</span><span>3</span></div>
    <div class="name">Trace &amp; Count</div>
    <div class="tag">✏️ Trace · 🍎 Count · 🎈 Pop</div>
  </div>
  </body></html>`;
}

async function renderHtml(browser, html, W, H, file) {
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  await page.setContent(html, { waitUntil: 'load' });
  await page.evaluate(() => Promise.all([500, 700, 800].map((w) => document.fonts.load(`${w} 20px "Baloo 2"`))));
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: file, type: 'jpeg', quality: 90 });
  await page.close();
}

// ---------- slides ----------

const SLIDES = [
  ['home', 'Learn 1 2 3 the fun way!', 'Tracing, counting and games for little learners', '#7c5ce6', '#b59cff'],
  ['trace', 'Trace every number', 'Follow the green dot from 0 all the way to 20', '#ff5a5f', '#ffa3a0'],
  ['guide', 'A helping hand shows the way', 'Arrows and a demo hand teach every stroke', '#2f9bff', '#8fd0ff'],
  ['reward', 'Earn stars and count along', 'Each number ends with a counting reward', '#ffb020', '#ffd76e'],
  ['count', 'Tap to count', 'Count out loud, then pick how many', '#27b04f', '#8fe3a6'],
  ['pop', 'Pop the number balloons', 'Listen, find and pop the right number', '#ff5aa5', '#ffb3d6'],
  ['pick', 'Collect stars for all 21 numbers', 'Works offline and saves progress on the device', '#7c5ce6', '#b59cff'],
];
const TABLET_SLIDES = ['trace', 'reward', 'count', 'pop'];

const DEVICES = [
  { dir: 'phone', W: 1080, H: 1920, vw: 360, vh: 640, dpr: 3, slides: SLIDES.map((s) => s[0]) },
  { dir: 'tablet-7', W: 1200, H: 1920, vw: 600, vh: 960, dpr: 2, slides: TABLET_SLIDES },
  { dir: 'tablet-10', W: 1600, H: 2560, vw: 800, vh: 1280, dpr: 2, slides: TABLET_SLIDES },
];

async function main() {
  const server = await serve();
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  try {
    await fs.mkdir(STORE, { recursive: true });

    const rounded = iconSvg({ rounded: true });
    const square = iconSvg({ rounded: false });
    await fs.writeFile(path.join(ICONS, 'icon.svg'), rounded);
    await renderSvg(browser, rounded, 192, path.join(ICONS, 'icon-192.png'), { transparent: true });
    await renderSvg(browser, rounded, 512, path.join(ICONS, 'icon-512.png'), { transparent: true });
    await renderSvg(browser, square, 512, path.join(ICONS, 'maskable-512.png'), { transparent: false });
    await renderSvg(browser, square, 512, path.join(STORE, 'icon-512.png'), { transparent: false });
    console.log('icons done');

    let phoneTrace;
    for (const dev of DEVICES) {
      const dir = path.join(STORE, dev.dir);
      await fs.rm(dir, { recursive: true, force: true });
      await fs.mkdir(dir, { recursive: true });
      for (const [i, name] of dev.slides.entries()) {
        const [, title, sub, c1, c2] = SLIDES.find((s) => s[0] === name);
        const shot = await captureScene(browser, base, name, dev);
        if (dev.dir === 'phone' && name === 'trace') phoneTrace = shot;
        const file = path.join(dir, `${String(i + 1).padStart(2, '0')}-${name}.jpg`);
        await renderHtml(browser, slideHtml({ W: dev.W, H: dev.H, title, sub, c1, c2, shot, base }), dev.W, dev.H, file);
        console.log(path.relative(ROOT, file));
      }
    }

    await renderHtml(browser, featureHtml({ shot: phoneTrace, base }), 1024, 500, path.join(STORE, 'feature-graphic.jpg'));
    console.log('store/feature-graphic.jpg');
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
