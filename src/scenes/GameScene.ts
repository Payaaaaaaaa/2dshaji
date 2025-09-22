import Phaser from 'phaser';

import { Player } from '../entities/Player';
import { ARENA_HEIGHT, ARENA_WIDTH, GAME_DURATION_SECONDS, INITIAL_LIVES } from '../utils/constants';
import { randomPointWithin } from '../utils/random';

interface GameOverPayload {
  victory: boolean;
  finalScore: number;
  collected: number;
  survivedSeconds: number;
}

export class GameScene extends Phaser.Scene {
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private player!: Player;
  private collectibles!: Phaser.Physics.Arcade.Group;
  private hazards!: Phaser.Physics.Arcade.Group;

  private score = 0;
  private collected = 0;
  private lives = INITIAL_LIVES;
  private elapsedSeconds = 0;
  private isGameOver = false;
  private lastRemainingSeconds = GAME_DURATION_SECONDS;

  constructor() {
    super('game');
  }

  create(): void {
    this.resetState();
    this.scene.launch('ui');

    this.cursors = this.input.keyboard!.createCursorKeys();
    this.createArena();
    this.createPlayer();
    this.createGroups();
    this.createColliders();
    this.registerTimers();

    this.events.emit('score-changed', this.score);
    this.events.emit('lives-changed', this.lives);
    this.events.emit('time-changed', this.lastRemainingSeconds);
  }

  update(_: number, delta: number): void {
    if (this.isGameOver) {
      return;
    }

    this.player.update(this.cursors);
    this.elapsedSeconds += delta / 1000;

    if (this.elapsedSeconds >= GAME_DURATION_SECONDS) {
      this.triggerGameOver(true);
      return;
    }

    const remaining = Math.max(0, Math.ceil(GAME_DURATION_SECONDS - this.elapsedSeconds));
    if (remaining !== this.lastRemainingSeconds) {
      this.lastRemainingSeconds = remaining;
      this.events.emit('time-changed', remaining);
    }
  }

  private resetState(): void {
    this.score = 0;
    this.collected = 0;
    this.lives = INITIAL_LIVES;
    this.elapsedSeconds = 0;
    this.isGameOver = false;
    this.lastRemainingSeconds = GAME_DURATION_SECONDS;
  }

  private createArena(): void {
    this.add.tileSprite(0, 0, ARENA_WIDTH, ARENA_HEIGHT, 'arena-tile').setOrigin(0, 0);
    const frame = this.add.rectangle(ARENA_WIDTH / 2, ARENA_HEIGHT / 2, ARENA_WIDTH - 12, ARENA_HEIGHT - 12);
    frame.setStrokeStyle(4, 0x293241, 0.9);
  }

  private createPlayer(): void {
    this.player = new Player(this, ARENA_WIDTH / 2, ARENA_HEIGHT / 2);
  }

  private createGroups(): void {
    this.collectibles = this.physics.add.group({
      classType: Phaser.Physics.Arcade.Image,
      runChildUpdate: false,
      allowGravity: false,
    });

    this.hazards = this.physics.add.group({
      classType: Phaser.Physics.Arcade.Image,
      runChildUpdate: false,
      allowGravity: false,
    });
  }

  private createColliders(): void {
    this.physics.add.overlap(this.player, this.collectibles, this.handleCollect, undefined, this);
    this.physics.add.overlap(this.player, this.hazards, this.handleHit, undefined, this);
  }

  private registerTimers(): void {
    this.time.addEvent({
      delay: 1100,
      loop: true,
      callback: () => this.spawnCollectible(),
    });

    this.time.addEvent({
      delay: 2100,
      loop: true,
      callback: () => this.spawnHazard(),
    });
  }

  private spawnCollectible(): void {
    if (this.isGameOver) return;

    const { x, y } = randomPointWithin({ width: ARENA_WIDTH, height: ARENA_HEIGHT, margin: 40 });
    const collectible = this.collectibles.get(x, y, 'collectible') as Phaser.Physics.Arcade.Image;
    const size = Phaser.Math.Between(26, 36);
    collectible.setActive(true);
    collectible.setVisible(true);
    collectible.setDisplaySize(size, size);
    collectible.setCircle(size / 2);
    collectible.setVelocity(0, 0);
    collectible.setImmovable(true);
  }

  private spawnHazard(): void {
    if (this.isGameOver) return;

    const spawn = randomPointWithin({ width: ARENA_WIDTH, height: ARENA_HEIGHT, margin: 40 });
    const hazard = this.hazards.get(spawn.x, spawn.y, 'hazard') as Phaser.Physics.Arcade.Image;
    hazard.setActive(true);
    hazard.setVisible(true);
    const size = Phaser.Math.Between(42, 62);
    hazard.setDisplaySize(size, size * 1.1);
    hazard.setCircle(Math.min(hazard.displayWidth, hazard.displayHeight) / 2.4);
    hazard.setCollideWorldBounds(true, 1, 1);
    hazard.setBounce(1, 1);

    const target = randomPointWithin({ width: ARENA_WIDTH, height: ARENA_HEIGHT, margin: 60 });
    const direction = new Phaser.Math.Vector2(target.x - spawn.x, target.y - spawn.y).normalize();
    hazard.setVelocity(direction.x * 140, direction.y * 140);
  }

  private handleCollect: Phaser.Types.Physics.Arcade.ArcadePhysicsCallback = (player, item) => {
    const collectible = item as Phaser.Physics.Arcade.Image;
    collectible.disableBody(true, true);
    this.score += 100;
    this.collected += 1;
    this.events.emit('score-changed', this.score);
    this.tweens.add({
      targets: player,
      scale: { from: 1.05, to: 1 },
      duration: 150,
    });
  };

  private handleHit: Phaser.Types.Physics.Arcade.ArcadePhysicsCallback = (_player, item) => {
    if (this.isGameOver) return;
    const hazard = item as Phaser.Physics.Arcade.Image;
    hazard.disableBody(true, true);
    this.lives -= 1;
    this.events.emit('lives-changed', this.lives);
    this.cameras.main.flash(200, 255, 107, 107);
    if (this.lives <= 0) {
      this.triggerGameOver(false);
    }
  };

  private triggerGameOver(victory: boolean): void {
    if (this.isGameOver) return;
    this.isGameOver = true;
    this.player.setVelocity(0, 0);
    this.time.removeAllEvents();
    this.collectibles.children.each((child) => {
      const sprite = child as Phaser.Physics.Arcade.Image;
      sprite.setVelocity(0, 0);
      return true;
    });
    this.hazards.children.each((child) => {
      const sprite = child as Phaser.Physics.Arcade.Image;
      sprite.setVelocity(0, 0);
      return true;
    });

    const payload: GameOverPayload = {
      victory,
      finalScore: this.score,
      collected: this.collected,
      survivedSeconds: Math.floor(this.elapsedSeconds),
    };

    this.events.emit('game-over', payload);
  }
}
