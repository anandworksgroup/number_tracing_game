# 123 Trace & Count

A preschool numbers game inspired by *Learn to Write 123 – Numbers, Counting & Tracing*.
It is an installable web app (PWA) that works offline on phones, tablets and desktops.
All art, sounds and code are original: the graphics are drawn in code or use emoji, the
sound effects are synthesized with Web Audio, and the numbers are spoken with the device's
speech engine.

## Games

- **✏️ Trace** – trace the numbers 0–20 stroke by stroke.
  - A green dot marks where to start, animated arrows show the direction, and a star marks where each stroke ends.
  - A demo hand 👆 shows each stroke first. Tap 👆 to see it again.
  - Numbered badges show the order of multi-stroke numbers (4, 5 and two-digit numbers).
  - Pick a crayon colour. Going off the path makes the board wobble but keeps the progress so far.
  - Finishing a number gives 1–3 stars (fewer slips means more stars), confetti, and a reward
    that counts that many objects out loud.
- **🍎 Count** – tap each object to count it aloud, then pick how many there are.
- **🎈 Pop** – pop only the balloons with the spoken target number. Popping five finishes the round.

Stars are saved on the device (`localStorage`). The home screen has toggles for sound
effects and voice, plus a reset button for parents.

## Run it

```bash
npm start        # serves on http://localhost:8080
npm test         # unit tests for digit stroke geometry
```

No build step and no runtime dependencies: it is plain HTML, CSS and ES modules.
You can host it on any static web server, for example GitHub Pages.

## App icon and Play Store graphics

```bash
npm install                  # dev tools: Playwright and the Baloo 2 font
npx playwright install chromium   # first time only, if Chromium isn't installed yet
npm run store-assets
```

`tools/store-assets.mjs` draws the app icon from the same stroke paths the child traces, then
drives the real app with Playwright to take screenshots. It writes:

- `icons/`: app icons (`icon.svg`, `icon-192.png`, `icon-512.png`, `maskable-512.png`)
- `store/icon-512.png`: Play Store icon
- `store/feature-graphic.jpg`: 1024 × 500 feature graphic
- `store/phone/`, `store/tablet-7/`, `store/tablet-10/`: framed screenshots with captions

Re-run it after changing the app so the store graphics stay current.
`store/listing.md` has draft store text (name, descriptions, category, content rating notes).

## Installing on Android / publishing

- **Install as an app:** open the hosted URL in Chrome and choose *Add to Home screen*.
- **Google Play:** wrap the hosted PWA with [Bubblewrap](https://github.com/GoogleChromeLabs/bubblewrap)
  (Trusted Web Activity) or [Capacitor](https://capacitorjs.com/) to produce an `.aab`.

## Project layout

| Path | Purpose |
| --- | --- |
| `js/digits.js` | Handwriting stroke paths for 0–9 and number layout |
| `js/trace.js` | Tracing engine: follows the finger along the path, draws the board |
| `js/count.js`, `js/balloons.js` | Counting and balloon mini games |
| `js/fx.js` | Confetti and the reward popup |
| `js/audio.js` | Synthesized sound effects and speech |
| `js/app.js` | Screens, navigation and saved progress |
| `sw.js`, `manifest.webmanifest`, `icons/` | Offline support and install metadata |
| `tools/store-assets.mjs` | Generates icons, screenshots and the feature graphic |
| `store/` | Google Play graphics and listing text |
