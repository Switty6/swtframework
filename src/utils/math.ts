export interface Vector2 {
  x: number;
  y: number;
}

export interface CircleCenter extends Vector2 {
  z: number;
}

export function distance2D(a: Vector2, b: Vector2): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

export function randomPointInCircle(center: CircleCenter, radius: number): CircleCenter {
  const t = 2 * Math.PI * Math.random();
  const u = Math.random() + Math.random();
  const r = u > 1 ? 2 - u : u;
  const x = center.x + radius * r * Math.cos(t);
  const y = center.y + radius * r * Math.sin(t);
  return { x, y, z: center.z };
}
