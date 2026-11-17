// Keyboard + floating virtual analog stick (left half of the screen).

export class Input {
  keys = new Set<string>();
  stick = { active: false, id: -1, ox: 0, oy: 0, x: 0, y: 0 };
  actionPressed = false;
  private pressedOnce = new Set<string>();
  readonly maxRadius = 56;

  constructor(private el: HTMLElement) {
    window.addEventListener('keydown', e => {
      if ((e.target as HTMLElement)?.tagName === 'INPUT') return;
      const k = e.key.toLowerCase();
      if (!this.keys.has(k)) this.pressedOnce.add(k);
      this.keys.add(k);
      if ([' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(k)) e.preventDefault();
    });
    window.addEventListener('keyup', e => this.keys.delete(e.key.toLowerCase()));
    window.addEventListener('blur', () => this.keys.clear());

    el.addEventListener('pointerdown', e => {
      if (this.stick.active) return;
      if (e.clientX > window.innerWidth * 0.6 && e.pointerType !== 'mouse') return;
      this.stick = { active: true, id: e.pointerId, ox: e.clientX, oy: e.clientY, x: e.clientX, y: e.clientY };
      el.setPointerCapture(e.pointerId);
    });
    el.addEventListener('pointermove', e => {
      if (!this.stick.active || e.pointerId !== this.stick.id) return;
      this.stick.x = e.clientX; this.stick.y = e.clientY;
    });
    const end = (e: PointerEvent) => {
      if (e.pointerId !== this.stick.id) return;
      this.stick.active = false; this.stick.id = -1;
    };
    el.addEventListener('pointerup', end);
    el.addEventListener('pointercancel', end);
  }

  /** Returns a movement vector with length 0..1 */
  move(): { x: number; y: number } {
    let x = 0, y = 0;
    if (this.keys.has('a') || this.keys.has('arrowleft')) x -= 1;
    if (this.keys.has('d') || this.keys.has('arrowright')) x += 1;
    if (this.keys.has('w') || this.keys.has('arrowup')) y -= 1;
    if (this.keys.has('s') || this.keys.has('arrowdown')) y += 1;
    if (x || y) { const l = Math.hypot(x, y); return { x: x / l, y: y / l }; }
    if (this.stick.active) {
      const dx = this.stick.x - this.stick.ox, dy = this.stick.y - this.stick.oy;
      const l = Math.hypot(dx, dy);
      if (l < 6) return { x: 0, y: 0 };
      const m = Math.min(1, l / this.maxRadius);
      return { x: (dx / l) * m, y: (dy / l) * m };
    }
    return { x: 0, y: 0 };
  }

  /** True once per key press */
  consume(key: string): boolean {
    if (this.pressedOnce.has(key)) { this.pressedOnce.delete(key); return true; }
    return false;
  }

  endFrame() { this.pressedOnce.clear(); this.actionPressed = false; }
}
