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
// Screenshots are taken from the Flutter app (built for the web, driven by Playwright),
// so `flutter` must be on PATH, or flutter_app/build/web must already be built.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { chromium, devices } from 'playwright';
import { DIGITS, DIGIT_ADVANCE, layoutNumber } from '../js/digits.js';

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
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.mjs': 'text/javascript',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wav': 'audio/wav',
};

function serve(root = ROOT) {
  const server = http.createServer(async (req, res) => {
    const p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    const [dir, rel] = p.startsWith('/__fonts/') ? [FONT_DIR, p.slice(9)] : [root, p === '/' ? 'index.html' : p];
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
// Android adaptive icons use separate layers: `background: false` gives the
// foreground only, `foreground: false` the background only, and `safe` shrinks
// the artwork into the adaptive icon's safe zone.
function iconSvg({ rounded, background = true, foreground = true, safe = false }) {
  const s = safe ? 0.8 : 1.08;
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
  ${background ? `<rect width="512" height="512"${rounded ? ' rx="112"' : ''} fill="url(#bg)"/>
  <circle cx="256" cy="266" r="200" fill="#ffffff" opacity="0.1"/>` : ''}
  ${foreground ? `<g transform="translate(${tx.toFixed(1)} ${ty.toFixed(1)}) scale(${s})" fill="none" stroke-linecap="round" stroke-linejoin="round">
    <g transform="translate(0 6)">${layer(() => 'stroke="#2a1b66" stroke-opacity="0.35" stroke-width="40"')}</g>
    ${layer(() => 'stroke="#ffffff" stroke-width="40"')}
    ${layer((p) => `stroke="${p.c}" stroke-width="27"`)}
  </g>
  ${
    safe
      ? `<polygon points="${starPoints(352, 178, 30, 13)}" fill="#ffd23f" stroke="#ffffff" stroke-width="6" stroke-linejoin="round"/>`
      : `<polygon points="${starPoints(392, 126, 40, 17)}" fill="#ffd23f" stroke="#ffffff" stroke-width="7" stroke-linejoin="round"/>
  <circle cx="128" cy="400" r="9" fill="#ffffff" opacity="0.8"/>
  <circle cx="408" cy="392" r="6" fill="#ffffff" opacity="0.7"/>
  <circle cx="112" cy="136" r="6" fill="#ffffff" opacity="0.7"/>`
  }` : ''}
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
//
// Screenshots come from the Flutter app (flutter_app/), the version published on Google Play.
// It is built for the web and run in Chromium with an Android user agent, so Flutter uses its
// Android look and behaviour; the web build renders with the same engine, fonts and emoji as
// the Android app, which runs full screen without system bars.

const FLUTTER_APP = path.join(ROOT, 'flutter_app');
const FLUTTER_WEB = path.join(FLUTTER_APP, 'build/web');
const ANDROID_UA = devices['Pixel 7'].userAgent;

// Saved progress in the format shared_preferences uses on the web.
const PROGRESS = {
  stars: { 0: 3, 1: 3, 2: 3, 3: 2, 4: 3, 5: 1, 6: 2, 7: 3, 8: 1 },
  trophies: 4,
  sound: true,
  voice: true,
};

function buildFlutterWeb() {
  try {
    execFileSync('flutter', ['build', 'web', '--release', '--no-web-resources-cdn'], { cwd: FLUTTER_APP, stdio: 'inherit' });
  } catch (e) {
    if (e.code !== 'ENOENT') throw e;
    console.warn('flutter not found on PATH; using the existing flutter_app/build/web');
  }
}

async function openApp(browser, base, { vw, vh, dpr }) {
  const ctx = await browser.newContext({
    viewport: { width: vw, height: vh },
    deviceScaleFactor: dpr,
    userAgent: ANDROID_UA,
    locale: 'en-US',
    serviceWorkers: 'block',
    // Flutter's web engine downloads its emoji font from fonts.gstatic.com; don't let a
    // TLS-inspecting proxy break that. (On Android the emoji come from the system font.)
    ignoreHTTPSErrors: true,
  });
  await ctx.addInitScript((p) => localStorage.setItem('flutter.trace123', JSON.stringify(JSON.stringify(p))), PROGRESS);
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(base + '/');
  // Turn on Flutter's accessibility tree so buttons can be found by their labels.
  await page.locator('flt-semantics-placeholder').click({ force: true, timeout: 60000 });
  await page.getByRole('button', { name: 'Trace', exact: true }).waitFor();
  await page.waitForTimeout(1500); // let emoji and fonts finish loading
  return { ctx, page, errors };
}

const button = (page, name) => page.getByRole('button', { name, exact: true });

async function tap(page, name, wait = 900) {
  await button(page, name).click();
  await page.waitForTimeout(wait);
}

// Screen positions of a number's strokes on the tracing board, using the same fit as the app.
async function strokesOnScreen(page, n) {
  const label = page.getByText(`Tracing board: trace the number ${n}`, { exact: true });
  const r = await page.locator('flt-semantics').filter({ has: label }).last().boundingBox();
  const layout = layoutNumber(n);
  const pad = 22;
  const s = Math.min(r.width / (layout.width + pad * 2), r.height / (layout.height + pad * 2));
  const ox = r.x + (r.width - layout.width * s) / 2;
  const oy = r.y + (r.height - layout.height * s) / 2;
  return layout.strokes.map((pts) => pts.map(([x, y]) => [ox + x * s, oy + y * s]));
}

// Drag the mouse along a stroke; `upto` < 1 stops part way with the finger still down.
async function drag(page, pts, upto = 1) {
  const end = Math.floor((pts.length - 1) * upto);
  await page.mouse.move(...pts[0]);
  await page.mouse.down();
  for (let i = 0; i <= end; i += 3) await page.mouse.move(...pts[i]);
  await page.mouse.move(...pts[end]);
  if (upto >= 1) {
    await page.mouse.up();
    await page.waitForTimeout(300);
  }
}

async function openNumber(page, n, wait = 1200) {
  await tap(page, 'Trace');
  await page.getByRole('button', { name: new RegExp(`^Number ${n},`) }).click();
  await page.waitForTimeout(wait);
}

const SCENES = {
  async home(page) {
    // The home screen is the first thing shown, so give its emoji time to download.
    await page.waitForTimeout(4000);
  },
  async trace(page) {
    await openNumber(page, 2);
    const [stroke] = await strokesOnScreen(page, 2);
    await drag(page, stroke, 0.62);
    await page.waitForTimeout(150);
  },
  async guide(page) {
    // The demo hand plays when a number opens; catch it part way along the stroke.
    // Open the number once first so the hand emoji is already loaded.
    await openNumber(page, 8, 2500);
    await tap(page, 'Back', 900);
    await page.getByRole('button', { name: /^Number 8,/ }).click();
    await page.waitForTimeout(1150);
  },
  async reward(page) {
    await openNumber(page, 4);
    for (const stroke of await strokesOnScreen(page, 4)) await drag(page, stroke);
    await page.waitForTimeout(5200); // counting animation
  },
  async count(page) {
    await tap(page, 'Count');
    // Re-enter until there are enough objects to make a busy picture.
    for (let i = 0; i < 20 && (await button(page, 'Tap to count').count()) < 6; i++) {
      await tap(page, 'Back', 700);
      await tap(page, 'Count');
    }
    const n = await button(page, 'Tap to count').count();
    for (let i = 0; i < Math.ceil(n * 0.6); i++) await button(page, 'Tap to count').first().click();
    await page.waitForTimeout(1200);
  },
  async pop(page) {
    await tap(page, 'Pop', 5600);
  },
  async pick(page) {
    await tap(page, 'Trace', 1200);
  },
};

async function captureScene(browser, base, name, dev) {
  const { ctx, page, errors } = await openApp(browser, base, dev);
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
  buildFlutterWeb();
  const server = await serve();
  const appServer = await serve(FLUTTER_WEB);
  const base = `http://127.0.0.1:${server.address().port}`;
  const appBase = `http://127.0.0.1:${appServer.address().port}`;
  // Software WebGL, for machines without a GPU (Flutter renders with WebGL).
  const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader'] });
  try {
    await fs.mkdir(STORE, { recursive: true });

    const rounded = iconSvg({ rounded: true });
    const square = iconSvg({ rounded: false });
    await fs.writeFile(path.join(ICONS, 'icon.svg'), rounded);
    await renderSvg(browser, rounded, 192, path.join(ICONS, 'icon-192.png'), { transparent: true });
    await renderSvg(browser, rounded, 512, path.join(ICONS, 'icon-512.png'), { transparent: true });
    await renderSvg(browser, square, 512, path.join(ICONS, 'maskable-512.png'), { transparent: false });
    await renderSvg(browser, square, 512, path.join(STORE, 'icon-512.png'), { transparent: false });

    // Flutter launcher icons (see flutter_app/pubspec.yaml, flutter_launcher_icons).
    const flutterIcons = path.join(ROOT, 'flutter_app/assets/icon');
    await fs.mkdir(flutterIcons, { recursive: true });
    await renderSvg(browser, square, 1024, path.join(flutterIcons, 'icon.png'), { transparent: false });
    await renderSvg(browser, iconSvg({ rounded: false, background: false, safe: true }), 1024, path.join(flutterIcons, 'foreground.png'), {
      transparent: true,
    });
    await renderSvg(browser, iconSvg({ rounded: false, foreground: false }), 1024, path.join(flutterIcons, 'background.png'), {
      transparent: false,
    });
    console.log('icons done');

    let phoneTrace;
    for (const dev of DEVICES) {
      // Capture everything first so a failure leaves the existing screenshots untouched.
      const shots = [];
      for (const name of dev.slides) shots.push(await captureScene(browser, appBase, name, dev));
      const dir = path.join(STORE, dev.dir);
      await fs.rm(dir, { recursive: true, force: true });
      await fs.mkdir(dir, { recursive: true });
      for (const [i, name] of dev.slides.entries()) {
        const [, title, sub, c1, c2] = SLIDES.find((s) => s[0] === name);
        const shot = shots[i];
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
    appServer.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
