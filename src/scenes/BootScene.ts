import Phaser from 'phaser';

/**
 * BootScene is responsible for creating reusable textures that are shared
 * throughout the game. Using programmatically generated textures keeps the
 * project asset-light while still providing visual variety.
 */
export class BootScene extends Phaser.Scene {
  constructor() {
    super('boot');
  }

  preload(): void {
    this.createPlayerTexture();
    this.createCollectibleTexture();
    this.createHazardTexture();
    this.createBackgroundTexture();
  }

  create(): void {
    this.scene.start('menu');
  }

  private createPlayerTexture(): void {
    const size = 64;
    const graphics = this.add.graphics({ x: 0, y: 0 });
    graphics.setVisible(false);
    graphics.fillStyle(0x56ccf2, 1);
    graphics.fillCircle(size / 2, size / 2, size / 2 - 4);

    graphics.lineStyle(6, 0xffffff, 0.8);
    graphics.strokeCircle(size / 2, size / 2, size / 2 - 10);

    graphics.generateTexture('player', size, size);
    graphics.destroy();
  }

  private createCollectibleTexture(): void {
    const size = 32;
    const graphics = this.add.graphics({ x: 0, y: 0 });
    graphics.setVisible(false);
    graphics.fillStyle(0xffd166, 1);
    graphics.fillCircle(size / 2, size / 2, size / 2 - 2);
    graphics.lineStyle(4, 0xf3722c, 0.9);
    graphics.strokeCircle(size / 2, size / 2, size / 2 - 6);
    graphics.generateTexture('collectible', size, size);
    graphics.destroy();
  }

  private createHazardTexture(): void {
    const width = 48;
    const height = 56;
    const graphics = this.add.graphics({ x: 0, y: 0 });
    graphics.setVisible(false);
    graphics.fillStyle(0xff6b6b, 1);
    graphics.fillTriangle(4, height - 4, width / 2, 4, width - 4, height - 4);
    graphics.lineStyle(4, 0x222222, 0.9);
    graphics.strokeTriangle(4, height - 4, width / 2, 4, width - 4, height - 4);
    graphics.generateTexture('hazard', width, height);
    graphics.destroy();
  }

  private createBackgroundTexture(): void {
    const width = 32;
    const height = 32;
    const graphics = this.add.graphics({ x: 0, y: 0 });
    graphics.setVisible(false);
    graphics.fillStyle(0x111827, 1);
    graphics.fillRect(0, 0, width, height);
    graphics.lineStyle(2, 0x1f2937, 0.6);
    graphics.strokeRoundedRect(2, 2, width - 4, height - 4, 6);
    graphics.generateTexture('arena-tile', width, height);
    graphics.destroy();
  }
}
