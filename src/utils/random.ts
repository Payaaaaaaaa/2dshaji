import Phaser from 'phaser';

interface Bounds {
  width: number;
  height: number;
  margin?: number;
}

export function randomPointWithin({ width, height, margin = 0 }: Bounds): { x: number; y: number } {
  const safeMargin = Math.min(margin, width / 2, height / 2);
  const x = Phaser.Math.Between(safeMargin, width - safeMargin);
  const y = Phaser.Math.Between(safeMargin, height - safeMargin);
  return { x, y };
}
