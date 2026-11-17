import './style.css';
import { Input } from './core/input';
import { Game } from './game/game';
import { UI } from './ui/ui';

const canvas = document.getElementById('game') as HTMLCanvasElement;
const input = new Input(canvas);
const game = new Game(canvas, input);
const ui = new UI(game);
ui.showTitle();

let last = performance.now();
function frame(now: number) {
  const dt = Math.min(0.1, (now - last) / 1000);
  last = now;
  game.update(dt);
  game.render();
  ui.updateHud(dt);
  if (game.paused) input.endFrame();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

document.addEventListener('visibilitychange', () => { if (document.hidden && game.world) game.save(); });
// Expose for debugging in the console.
(window as unknown as { game: Game }).game = game;
