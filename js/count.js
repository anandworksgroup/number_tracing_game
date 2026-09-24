// Count game: tap every object to count it, then pick how many there are.
import { sfx, speak, sayNumber } from './audio.js';
import { reward, EMOJIS } from './fx.js';

export class CountGame {
  constructor(root, { onWin }) {
    this.root = root;
    this.onWin = onWin;
    this.field = root.querySelector('.count-field');
    this.prompt = root.querySelector('.count-prompt');
    this.choices = root.querySelector('.count-choices');
    this.last = 0;
  }

  start() {
    let n;
    do n = 1 + Math.floor(Math.random() * 10);
    while (n === this.last);
    this.last = n;
    this.n = n;
    this.counted = 0;
    this.emoji = EMOJIS[Math.floor(Math.random() * EMOJIS.length)];
    this.prompt.textContent = 'Tap each one to count!';
    this.choices.innerHTML = '';
    this.field.innerHTML = '';
    for (let i = 0; i < n; i++) {
      const b = document.createElement('button');
      b.className = 'count-obj';
      b.style.setProperty('--d', `${i * 60}ms`);
      b.textContent = this.emoji;
      b.onclick = () => this.count(b);
      this.field.appendChild(b);
    }
    speak('How many? Tap to count!');
  }

  count(b) {
    if (b.dataset.n) return;
    this.counted++;
    b.dataset.n = this.counted;
    b.classList.add('counted');
    sfx.tap();
    sayNumber(this.counted);
    if (this.counted === this.n) setTimeout(() => this.ask(), 600);
  }

  ask() {
    this.prompt.textContent = 'How many?';
    const opts = new Set([this.n]);
    while (opts.size < 3) {
      const d = this.n + (Math.floor(Math.random() * 5) - 2);
      if (d >= 1 && d <= 12) opts.add(d);
    }
    this.choices.innerHTML = '';
    [...opts]
      .sort(() => Math.random() - 0.5)
      .forEach((v) => {
        const b = document.createElement('button');
        b.className = 'bubble';
        b.textContent = v;
        b.onclick = () => this.answer(v, b);
        this.choices.appendChild(b);
      });
    speak('How many?');
  }

  answer(v, b) {
    if (v !== this.n) {
      sfx.oops();
      b.classList.remove('shake');
      void b.offsetWidth;
      b.classList.add('shake');
      speak('Try again!');
      return;
    }
    b.classList.add('right');
    this.onWin?.();
    reward({
      title: `Yes! ${this.n}!`,
      stars: 3,
      onNext: () => this.start(),
    });
  }
}
