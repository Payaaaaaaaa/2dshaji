import Phaser from 'phaser';

import { PLAYER_SPEED } from '../utils/constants';

export class Player extends Phaser.Physics.Arcade.Sprite {
  private readonly speed: number;
  private readonly bodyInstance: Phaser.Physics.Arcade.Body;

  constructor(scene: Phaser.Scene, x: number, y: number) {
    super(scene, x, y, 'player');
    scene.add.existing(this);
    scene.physics.add.existing(this);

    this.speed = PLAYER_SPEED;
    this.bodyInstance = this.body as Phaser.Physics.Arcade.Body;
    this.bodyInstance.setCollideWorldBounds(true);
    this.bodyInstance.setCircle(this.width / 2 - 4);
  }

  update(cursors: Phaser.Types.Input.Keyboard.CursorKeys): void {
    const direction = new Phaser.Math.Vector2(0, 0);
    if (cursors.left?.isDown) {
      direction.x -= 1;
    }
    if (cursors.right?.isDown) {
      direction.x += 1;
    }
    if (cursors.up?.isDown) {
      direction.y -= 1;
    }
    if (cursors.down?.isDown) {
      direction.y += 1;
    }

    direction.normalize();
    this.bodyInstance.setVelocity(direction.x * this.speed, direction.y * this.speed);

    if (!direction.equals(Phaser.Math.Vector2.ZERO)) {
      this.rotation = Phaser.Math.Angle.Between(0, 0, direction.x, direction.y);
    }
  }
}
