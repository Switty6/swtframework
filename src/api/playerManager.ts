import { recordPlayerJoin, markPlayerDeath, updatePlayerStats } from '../db/eventRepo';
import config from '../config/config.json';
import { CircleCenter } from '../utils/math';
import { logEvent } from '../utils/logger';
import * as spectatorManager from './spectatorManager';

export interface ManagedPlayer {
  entity: RageMP.PlayerMp;
  identifier: string;
  name: string;
  alive: boolean;
  kills: number;
  damageTaken: number;
  lastInCircleAt?: number;
  immunityUntil?: number;
}

let currentEventId: number | null = null;
const players = new Map<number, ManagedPlayer>();
let eliminationCallback: (player: ManagedPlayer) => void = () => {};

function getIdentifier(player: RageMP.PlayerMp): string {
  const variableId = player.getVariable?.('swt:identifier');
  if (variableId) {
    return String(variableId);
  }

  const nameBased = `${player.name || 'unknown'}-${player.id}`;
  return nameBased;
}

export function setEliminationHandler(handler: (player: ManagedPlayer) => void): void {
  eliminationCallback = handler;
}

export async function preparePlayers(eventId: number, center: CircleCenter): Promise<void> {
  currentEventId = eventId;
  players.clear();

  const mpPlayers: RageMP.PlayerMp[] = mp?.players?.toArray?.() ?? [];

  await Promise.all(
    mpPlayers.map(async (player) => {
      const identifier = getIdentifier(player);
      players.set(player.id, {
        entity: player,
        identifier,
        name: player.name,
        alive: true,
        kills: 0,
        damageTaken: 0,
      });

      if (currentEventId) {
        await recordPlayerJoin(currentEventId, identifier, player.name);
      }

      teleportPlayer(player, center);
      equipLoadout(player);
      player.setVariable?.('swt:event:alive', true);
      logEvent(eventId, 'JOIN', `${player.name} joined the event`);
    }),
  );
}

export function teleportPlayer(player: RageMP.PlayerMp, center: CircleCenter): void {
  if (player.vehicle) {
    player.vehicle.position = center;
  } else {
    player.spawn(center);
    player.position = center;
  }
}

export function equipLoadout(player: RageMP.PlayerMp): void {
  player.removeAllWeapons?.();
  player.setVariable?.('swt:event:bandages', 1);
}

export function healPlayer(player: RageMP.PlayerMp, amount: number): void {
  player.health = Math.min(100, player.health + amount);
}

export function getAlivePlayers(): ManagedPlayer[] {
  return Array.from(players.values()).filter((p) => p.alive);
}

export function updateLastInCircle(playerId: number): void {
  const managed = players.get(playerId);
  if (!managed || !currentEventId) {
    return;
  }

  managed.lastInCircleAt = Date.now();
  void updatePlayerStats(currentEventId, managed.identifier, {
    lastInCircleAt: new Date(managed.lastInCircleAt),
  });
}

export function registerPlayerDamage(playerId: number, amount: number): void {
  const managed = players.get(playerId);
  if (!managed || !currentEventId) {
    return;
  }

  managed.damageTaken += amount;
  void updatePlayerStats(currentEventId, managed.identifier, {
    damageTaken: managed.damageTaken,
  });
}

export function applyDamage(playerId: number, amount: number): void {
  const managed = players.get(playerId);
  if (!managed || !managed.alive) {
    return;
  }

  registerPlayerDamage(playerId, amount);

  managed.entity.health = Math.max(0, managed.entity.health - amount);
  if (managed.entity.health <= 0) {
    eliminatePlayer(managed);
  }
}

export function eliminatePlayer(managed: ManagedPlayer): void {
  if (!managed.alive) {
    return;
  }

  managed.alive = false;
  managed.entity.setVariable?.('swt:event:alive', false);
  managed.entity.outputChatBox?.('You have been eliminated!');
  spectatorManager.sendToSpectator(managed.entity);

  if (currentEventId) {
    void markPlayerDeath(currentEventId, managed.identifier);
    logEvent(currentEventId, 'ELIMINATED', `${managed.name} was eliminated`);
  }

  eliminationCallback(managed);
}

export function resetPlayers(): void {
  players.clear();
  currentEventId = null;
}

export function hasActiveEvent(): boolean {
  return currentEventId !== null;
}

export function isImmune(playerId: number): boolean {
  const managed = players.get(playerId);
  if (!managed) {
    return false;
  }

  if (!managed.immunityUntil) {
    return false;
  }

  return managed.immunityUntil > Date.now();
}

export function grantImmunity(playerId: number, seconds: number): void {
  const managed = players.get(playerId);
  if (!managed || !currentEventId) {
    return;
  }

  const until = Date.now() + seconds * 1000;
  managed.immunityUntil = until;
  managed.entity.outputChatBox?.(`You are immune for ${seconds} seconds!`);

  void updatePlayerStats(currentEventId, managed.identifier, {
    immunityUntil: new Date(until),
  });
  logEvent(currentEventId, 'IMMUNITY', `${managed.name} gained immunity for ${seconds}s`);
}

export function getManagedPlayer(playerId: number): ManagedPlayer | undefined {
  return players.get(playerId);
}

export function getEventId(): number | null {
  return currentEventId;
}

export function tpAllToCenter(centerOverride?: CircleCenter): void {
  const center = centerOverride ?? (config.center as CircleCenter);
  players.forEach((managed) => teleportPlayer(managed.entity, center));
}
