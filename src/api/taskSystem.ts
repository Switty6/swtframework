import config from '../config/config.json';
import { CircleCenter, randomPointInCircle } from '../utils/math';
import { logEvent } from '../utils/logger';
import * as playerManager from './playerManager';

interface TaskState {
  position: CircleCenter | null;
  expiresAt: number;
  grantsPistol: boolean;
  timeout?: NodeJS.Timeout;
}

let currentEventId: number | null = null;
let state: TaskState = {
  position: null,
  expiresAt: 0,
  grantsPistol: false,
};
let claimCallback: (data: TaskClaimEvent) => void = () => {};

export interface TaskClaimEvent {
  player: playerManager.ManagedPlayer;
  immunitySeconds: number;
  grantedPistol: boolean;
}

export function start(eventId: number): void {
  currentEventId = eventId;
  state = { position: null, expiresAt: 0, grantsPistol: false };
}

export function stop(): void {
  if (state.timeout) {
    clearTimeout(state.timeout);
  }
  state = { position: null, expiresAt: 0, grantsPistol: false };
  currentEventId = null;
  claimCallback = () => {};
}

export function setClaimCallback(callback: (data: TaskClaimEvent) => void): void {
  claimCallback = callback;
}

export function spawnImmunityPoint(center: CircleCenter, radius: number): void {
  if (!currentEventId) {
    return;
  }

  const position = randomPointInCircle(center, radius * 0.8);
  state.position = position;
  state.expiresAt = Date.now() + config.taskTimeout * 1000;
  state.grantsPistol = Math.random() < 0.2;

  broadcastToPlayers('swt:task:spawn', position, config.taskTimeout, state.grantsPistol);
  const pistolMessage = state.grantsPistol ? ' (pistol bonus active)' : '';
  logEvent(
    currentEventId,
    'TASK_SPAWN',
    `Immunity task spawned at (${position.x.toFixed(2)}, ${position.y.toFixed(2)})${pistolMessage}`,
  );

  if (state.timeout) {
    clearTimeout(state.timeout);
  }
  state.timeout = setTimeout(() => {
    if (!state.position) {
      return;
    }
    broadcastToPlayers('swt:task:expire');
    state = { position: null, expiresAt: 0, grantsPistol: false };
  }, config.taskTimeout * 1000);
}

export interface TaskClaimResult {
  success: boolean;
  grantedPistol: boolean;
  immunitySeconds: number;
}

export function claimImmunity(playerId: number): TaskClaimResult | null {
  if (!currentEventId || !state.position) {
    return null;
  }

  const managed = playerManager.getManagedPlayer(playerId);
  if (!managed || !managed.alive) {
    return null;
  }

  if (Date.now() > state.expiresAt) {
    return null;
  }

  playerManager.grantImmunity(playerId, config.immunitySeconds);
  broadcastToPlayers('swt:task:claimed', managed.entity.name);
  const grantedPistol = state.grantsPistol;
  if (grantedPistol) {
    managed.entity.giveWeapon?.('weapon_pistol', 6);
  }
  const pistolSuffix = grantedPistol ? ' with bonus pistol' : '';
  logEvent(currentEventId, 'TASK_CLAIMED', `${managed.name} claimed immunity${pistolSuffix}`);
  claimCallback({
    player: managed,
    immunitySeconds: config.immunitySeconds,
    grantedPistol,
  });
  state = { position: null, expiresAt: 0, grantsPistol: false };
  if (state.timeout) {
    clearTimeout(state.timeout);
  }
  return { success: true, grantedPistol, immunitySeconds: config.immunitySeconds };
}

export function getActiveTask(): CircleCenter | null {
  return state.position;
}

function broadcastToPlayers(event: string, ...args: unknown[]): void {
  playerManager
    .getAlivePlayers()
    .forEach((managed) => managed.entity.call?.(event, ...args));
}
