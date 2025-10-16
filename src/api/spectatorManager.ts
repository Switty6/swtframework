const SPECTATOR_DIMENSION = 999;

const spectatorTargets = new Map<number, number>();

export function sendToSpectator(player: RageMP.PlayerMp): void {
  player.dimension = SPECTATOR_DIMENSION;
  player.call?.('swt:spectator:mode', true);
  spectatorTargets.delete(player.id);
}

export function attachToPlayer(spectator: RageMP.PlayerMp, target: RageMP.PlayerMp): void {
  spectator.dimension = target.dimension;
  spectator.position = target.position;
  spectator.call?.('swt:spectator:attach', target.id);
  spectatorTargets.set(spectator.id, target.id);
}

export function detachSpectator(player: RageMP.PlayerMp): void {
  player.call?.('swt:spectator:detach');
  spectatorTargets.delete(player.id);
}

export function getTargetId(spectatorId: number): number | undefined {
  return spectatorTargets.get(spectatorId);
}

export function isSpectating(player: RageMP.PlayerMp): boolean {
  return spectatorTargets.has(player.id);
}
