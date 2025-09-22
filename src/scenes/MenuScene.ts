import Phaser from 'phaser';

import { ARENA_HEIGHT, ARENA_WIDTH } from '../utils/constants';

export class MenuScene extends Phaser.Scene {
  constructor() {
    super('menu');
  }

  create(): void {
    this.add.tileSprite(0, 0, ARENA_WIDTH, ARENA_HEIGHT, 'arena-tile')
      .setOrigin(0, 0)
      .setAlpha(0.6);

    const title = this.add.text(ARENA_WIDTH / 2, ARENA_HEIGHT / 2 - 120, 'Skybound Courier', {
      fontFamily: '"Trebuchet MS", sans-serif',
      fontSize: '64px',
      color: '#f8fafc',
    }).setOrigin(0.5);

    title.setShadow(0, 12, '#1e293b', 0, true, true);

    this.add
      .text(
        ARENA_WIDTH / 2,
        ARENA_HEIGHT / 2,
        `穿梭天空运送能量球，躲避红色风暴。\n收集越多，得分越高！`,
        {
          fontFamily: '"Trebuchet MS", sans-serif',
          fontSize: '20px',
          color: '#cbd5f5',
          align: 'center',
        }
      )
      .setOrigin(0.5);

    this.add.text(ARENA_WIDTH / 2, ARENA_HEIGHT / 2 + 120, '按下【Space】开始', {
      fontFamily: '"Trebuchet MS", sans-serif',
      fontSize: '24px',
      color: '#38bdf8',
    }).setOrigin(0.5);

    this.input.keyboard?.once('keydown-SPACE', () => {
      this.scene.start('game');
    });

    this.input.once(Phaser.Input.Events.POINTER_DOWN, () => {
      this.scene.start('game');
    });
  }
}
