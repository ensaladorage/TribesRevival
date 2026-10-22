import { BabylonGame } from './engine/BabylonGame';
import './styles.css';

const canvas = document.createElement('canvas');
canvas.id = 'game-canvas';
document.querySelector('#game-root')?.append(canvas);

const game = new BabylonGame(canvas);

if (import.meta.env.DEV) {
  window.addEventListener('beforeunload', () => game.destroy());
}
