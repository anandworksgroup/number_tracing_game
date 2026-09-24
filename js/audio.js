// Synthesized sound effects (no audio files) and spoken numbers.

export const settings = { sound: true, voice: true };

export const WORDS = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
  'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen',
  'eighteen', 'nineteen', 'twenty',
];

let ctx = null;
function ac() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

function tone(freq, { at = 0, dur = 0.15, type = 'sine', vol = 0.2, slide = 0 } = {}) {
  if (!settings.sound) return;
  const c = ac();
  if (!c) return;
  const t = c.currentTime + at;
  const osc = c.createOscillator();
  const gain = c.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t);
  if (slide) osc.frequency.exponentialRampToValueAtTime(freq * slide, t + dur);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(vol, t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  osc.connect(gain).connect(c.destination);
  osc.start(t);
  osc.stop(t + dur + 0.02);
}

export const sfx = {
  tap: () => tone(660, { dur: 0.08, type: 'triangle', vol: 0.15 }),
  tick: (i) => tone(500 + (i % 12) * 40, { dur: 0.05, type: 'sine', vol: 0.05 }),
  ding: () => {
    tone(880, { dur: 0.25, type: 'triangle' });
    tone(1320, { at: 0.08, dur: 0.3, type: 'sine', vol: 0.12 });
  },
  oops: () => tone(220, { dur: 0.25, type: 'sawtooth', vol: 0.08, slide: 0.6 }),
  pop: () => tone(900, { dur: 0.12, type: 'square', vol: 0.08, slide: 0.3 }),
  win: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, { at: i * 0.11, dur: 0.3, type: 'triangle' })),
};

export function speak(text) {
  if (!settings.voice || !('speechSynthesis' in window)) return;
  const synth = window.speechSynthesis;
  synth.cancel();
  const u = new SpeechSynthesisUtterance(String(text));
  u.rate = 0.9;
  u.pitch = 1.25;
  const en = synth.getVoices().find((v) => v.lang && v.lang.startsWith('en'));
  if (en) u.voice = en;
  synth.speak(u);
}

export const sayNumber = (n) => speak(WORDS[n] ?? n);
