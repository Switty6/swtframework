import { CircleCenter, randomPointInCircle } from '../utils/math';
import { logEvent } from '../utils/logger';
import * as playerManager from './playerManager';

const MELEE_WEAPONS = ['weapon_bat', 'weapon_knuckle', 'weapon_hammer'] as const;

export interface LootCallbacks {
  eventId: number;
  center: CircleCenter;
  radius: number;
  onLootCollected: (payload: LootCollectedPayload) => void;
  onFinalDropCollected: (payload: FinalDropCollectedPayload) => void;
}

export interface LootCollectedPayload {
  player: playerManager.ManagedPlayer;
  weapon: string;
  crateId: string;
}

export interface FinalDropCollectedPayload {
  player: playerManager.ManagedPlayer;
  weapon: string;
}

interface LootCrate {
  id: string;
  position: CircleCenter;
  weapon: string;
  taken: boolean;
}

interface FinalDropState {
  active: boolean;
  taken: boolean;
  position: CircleCenter | null;
}

interface InternalState {
  callbacks: LootCallbacks | null;
  crates: LootCrate[];
  lootPhaseEndsAt: number;
  lootPhaseTimer?: NodeJS.Timeout;
  finalDrop: FinalDropState;
}

const state: InternalState = {
  callbacks: null,
  crates: [],
  lootPhaseEndsAt: 0,
  finalDrop: { active: false, taken: false, position: null },
};

export function start(callbacks: LootCallbacks): void {
  state.callbacks = callbacks;
  state.finalDrop = { active: false, taken: false, position: null };
  spawnLootCrates(callbacks.center, callbacks.radius);
  state.lootPhaseEndsAt = Date.now() + 60_000;
  scheduleLootPhaseEnd();
  broadcastToPlayers('swt:loot:phaseStart', {
    crates: state.crates,
    endsAt: state.lootPhaseEndsAt,
  });
  logEvent(callbacks.eventId, 'LOOT_PHASE_START', 'Loot phase has started with melee crates');
}

export function stop(): void {
  if (state.lootPhaseTimer) {
    clearTimeout(state.lootPhaseTimer);
    state.lootPhaseTimer = undefined;
  }
  if (state.callbacks) {
    logEvent(state.callbacks.eventId, 'LOOT_PHASE_END', 'Loot phase stopped');
  }
  broadcastToPlayers('swt:loot:phaseEnd');
  state.callbacks = null;
  state.crates = [];
  state.lootPhaseEndsAt = 0;
  state.finalDrop = { active: false, taken: false, position: null };
}

export function collectCrate(playerId: number, crateId: string): LootCollectResult {
  if (!state.callbacks) {
    return { success: false, reason: 'No active loot phase.' };
  }

  if (state.lootPhaseEndsAt && Date.now() > state.lootPhaseEndsAt) {
    return { success: false, reason: 'Loot phase already ended.' };
  }

  const crate = state.crates.find((c) => c.id === crateId);
  if (!crate || crate.taken) {
    return { success: false, reason: 'Crate unavailable.' };
  }

  const managed = playerManager.getManagedPlayer(playerId);
  if (!managed || !managed.alive) {
    return { success: false, reason: 'Invalid player.' };
  }

  crate.taken = true;
  managed.entity.removeAllWeapons?.();
  managed.entity.giveWeapon?.(crate.weapon, 0);
  broadcastToPlayers('swt:loot:crateTaken', crateId, managed.entity.name);

  const payload: LootCollectedPayload = {
    player: managed,
    weapon: crate.weapon,
    crateId: crate.id,
  };

  state.callbacks.onLootCollected(payload);
  logEvent(state.callbacks.eventId, 'LOOT_COLLECT', `${managed.name} collected ${crate.weapon} from ${crate.id}`);
  broadcastChat(`${managed.name} armed up with ${crate.weapon}.`);

  return { success: true, weapon: crate.weapon };
}

export interface LootCollectResult {
  success: boolean;
  reason?: string;
  weapon?: string;
}

export function handleShrink(radius: number, center: CircleCenter): void {
  if (!state.callbacks) {
    return;
  }

  if (radius <= 50 && !state.finalDrop.active && !state.finalDrop.taken) {
    spawnFinalDrop(center);
  }
}

export function collectFinalDrop(playerId: number): FinalDropCollectResult {
  if (!state.callbacks || !state.finalDrop.active || state.finalDrop.taken || !state.finalDrop.position) {
    return { success: false, reason: 'No active final drop.' };
  }

  const managed = playerManager.getManagedPlayer(playerId);
  if (!managed || !managed.alive) {
    return { success: false, reason: 'Invalid player.' };
  }

  state.finalDrop.taken = true;
  state.finalDrop.active = false;
  managed.entity.giveWeapon?.('weapon_rpg', 1);
  broadcastToPlayers('swt:finaldrop:claimed', managed.entity.name);
  const payload: FinalDropCollectedPayload = {
    player: managed,
    weapon: 'weapon_rpg',
  };
  state.callbacks.onFinalDropCollected(payload);
  logEvent(state.callbacks.eventId, 'FINAL_DROP_CLAIM', `${managed.name} secured the final drop bazooka`);
  broadcastChat(`${managed.name} grabbed the bazooka!`);
  broadcastToPlayers('swt:finaldrop:despawn');

  return { success: true };
}

export interface FinalDropCollectResult {
  success: boolean;
  reason?: string;
}

function spawnLootCrates(center: CircleCenter, radius: number): void {
  state.crates = Array.from({ length: 3 }).map((_, index) => {
    const position = randomPointInCircle(center, radius * 0.7);
    const weapon = MELEE_WEAPONS[Math.floor(Math.random() * MELEE_WEAPONS.length)];
    return {
      id: `crate-${index + 1}`,
      position,
      weapon,
      taken: false,
    };
  });
  broadcastToPlayers('swt:loot:spawnCrates', state.crates);
}

function spawnFinalDrop(center: CircleCenter): void {
  if (!state.callbacks) {
    return;
  }
  state.finalDrop = { active: true, taken: false, position: center };
  broadcastToPlayers('swt:finaldrop:spawn', center);
  logEvent(state.callbacks.eventId, 'FINAL_DROP_SPAWN', 'Final drop spawned with bazooka reward');
  broadcastChat('🔥 The Final Drop has appeared! Whoever gets it can end the game.');
}

function scheduleLootPhaseEnd(): void {
  if (state.lootPhaseTimer) {
    clearTimeout(state.lootPhaseTimer);
  }
  const now = Date.now();
  const remaining = Math.max(0, state.lootPhaseEndsAt - now);
  state.lootPhaseTimer = setTimeout(() => {
    if (state.callbacks) {
      logEvent(state.callbacks.eventId, 'LOOT_PHASE_END', 'Loot phase timed out');
    }
    broadcastToPlayers('swt:loot:phaseEnd');
    broadcastChat('Loot phase over! Circle shrink and checkpoints are live.');
    state.crates = [];
    state.lootPhaseTimer = undefined;
  }, remaining);
}

function broadcastToPlayers(event: string, ...args: unknown[]): void {
  playerManager
    .getAlivePlayers()
    .forEach((managed) => managed.entity.call?.(event, ...args));
}

function broadcastChat(message: string): void {
  const players: RageMP.PlayerMp[] = mp?.players?.toArray?.() ?? [];
  players.forEach((player) => player.outputChatBox?.(`[SWT] ${message}`));
}
