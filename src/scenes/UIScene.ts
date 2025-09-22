import Phaser from 'phaser';

import { GameScene } from './GameScene';

interface GameOverPayload {
  victory: boolean;
  finalScore: number;
  collected: number;
  survivedSeconds: number;
}

export class UIScene extends Phaser.Scene {
  private scoreText!: Phaser.GameObjects.Text;
  private livesText!: Phaser.GameObjects.Text;
  private timeText!: Phaser.GameObjects.Text;
  private overlayContainer?: Phaser.GameObjects.Container;
  private gameScene?: GameScene;
  private isGameOver = false;

  constructor() {
    super('ui');
  }

  create(): void {
    this.gameScene = this.scene.get('game') as GameScene;

    this.scoreText = this.addText(24, 20, '分数: 0');
    this.livesText = this.addText(24, 60, '护盾: 3');
    this.timeText = this.addText(24, 100, '倒计时: 90s');

    this.registerEvents();
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, this.cleanup, this);
  }

  private addText(x: number, y: number, content: string): Phaser.GameObjects.Text {
    return this.add.text(x, y, content, {
      fontFamily: '"Trebuchet MS", sans-serif',
      fontSize: '26px',
      color: '#e2e8f0',
      stroke: '#0f172a',
      strokeThickness: 3,
    });
  }

  private registerEvents(): void {
    if (!this.gameScene) return;
    this.gameScene.events.on('score-changed', this.handleScoreChanged, this);
    this.gameScene.events.on('lives-changed', this.handleLivesChanged, this);
    this.gameScene.events.on('time-changed', this.handleTimeChanged, this);
    this.gameScene.events.on('game-over', this.handleGameOver, this);
  }

  private cleanup(): void {
    this.gameScene?.events.off('score-changed', this.handleScoreChanged, this);
    this.gameScene?.events.off('lives-changed', this.handleLivesChanged, this);
    this.gameScene?.events.off('time-changed', this.handleTimeChanged, this);
    this.gameScene?.events.off('game-over', this.handleGameOver, this);
    this.overlayContainer?.destroy(true);
    this.overlayContainer = undefined;
    this.isGameOver = false;
  }

  private handleScoreChanged = (score: number) => {
    this.scoreText.setText(`分数: ${score}`);
  };

  private handleLivesChanged = (lives: number) => {
    this.livesText.setText(`护盾: ${Math.max(lives, 0)}`);
  };

  private handleTimeChanged = (seconds: number) => {
    this.timeText.setText(`倒计时: ${Math.max(seconds, 0)}s`);
  };

  private handleGameOver = (payload: GameOverPayload) => {
    this.isGameOver = true;
    this.createOverlay(payload);
    this.input.keyboard?.once('keydown-SPACE', () => this.restartToMenu());
    this.input.once(Phaser.Input.Events.POINTER_DOWN, () => this.restartToMenu());
  };

  private createOverlay(payload: GameOverPayload): void {
    const { width, height } = this.scale;

    this.overlayContainer?.destroy();
    const container = this.add.container(width / 2, height / 2);
    const backdrop = this.add.rectangle(0, 0, width * 0.7, height * 0.6, 0x020617, 0.86);
    const border = this.add.rectangle(0, 0, width * 0.7, height * 0.6);
    border.setStrokeStyle(4, payload.victory ? 0x4ade80 : 0xf87171, 1);
    container.add([backdrop, border]);

    const title = this.add.text(0, -height * 0.2, payload.victory ? '胜利！' : '任务失败', {
      fontFamily: '"Trebuchet MS", sans-serif',
      fontSize: '46px',
      color: payload.victory ? '#bbf7d0' : '#fecdd3',
    }).setOrigin(0.5);
    container.add(title);

    const lines = [
      `最终得分：${payload.finalScore}`,
      `收集能量球：${payload.collected}`,
      `坚持时间：${payload.survivedSeconds}s`,
      '按下【Space】返回菜单',
    ];

    lines.forEach((line, index) => {
      const text = this.add.text(0, -40 + index * 40, line, {
        fontFamily: '"Trebuchet MS", sans-serif',
        fontSize: index === lines.length - 1 ? '22px' : '26px',
        color: '#f8fafc',
        align: 'center',
      }).setOrigin(0.5);
      container.add(text);
    });

    container.sendToBack(backdrop);
    this.overlayContainer = container;
  }

  private restartToMenu(): void {
    if (!this.isGameOver) return;
    this.scene.stop('game');
    this.scene.stop();
    this.scene.start('menu');
  }
}
