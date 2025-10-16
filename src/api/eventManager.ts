import config from '../config/config.json';
import {
  createEventRecord,
  updateEventState,
  setEventEnded,
  createEventResult,
} from '../db/eventRepo';
import { CircleCenter } from '../utils/math';
import { finalizeMatchLog, initMatchLog, logEvent } from '../utils/logger';
import * as circleSystem from './circleSystem';
import * as lootSystem from './lootSystem';
import * as playerManager from './playerManager';
import * as taskSystem from './taskSystem';

interface ActiveEvent {
  id: number;
  startedAt: number;
  center: CircleCenter;
  logPath?: string;
  name: string;
  initialPlayers: number;
  lootHistory: LootPickupSummary[];
  checkpointHistory: CheckpointClaimSummary[];
  finalDrop: FinalDropSummary | null;
}

interface LootPickupSummary {
  player: string;
  identifier: string;
  weapon: string;
  crateId: string;
  timestamp: string;
}

interface CheckpointClaimSummary {
  player: string;
  identifier: string;
  immunitySeconds: number;
  grantedPistol: boolean;
  timestamp: string;
}

interface FinalDropSummary {
  player: string;
  identifier: string;
  weapon: string;
  timestamp: string;
}

let activeEvent: ActiveEvent | null = null;

playerManager.setEliminationHandler((player) => {
  if (!activeEvent) {
    return;
  }

  const alive = playerManager.getAlivePlayers();
  if (alive.length === 1) {
    void declareWinner(alive[0]);
  } else if (alive.length === 0) {
    void declareWinner(player);
  }
});

circleSystem.setShrinkCallback((radius, center) => {
  if (!activeEvent) {
    return;
  }
  broadcastMessage(`Circle shrink! New radius: ${radius.toFixed(1)}`);
  taskSystem.spawnImmunityPoint(center, radius);
  lootSystem.handleShrink(radius, center);
});

export function isEventRunning(): boolean {
  return activeEvent !== null;
}

export async function startEvent(): Promise<void> {
  if (activeEvent) {
    throw new Error('Event already running');
  }

  const event = await createEventRecord('Shrinking Circle');
  const logPath = initMatchLog(event.id);
  logEvent(event.id, 'INIT', 'Event created');

  const center = config.center as CircleCenter;
  await playerManager.preparePlayers(event.id, center);
  const initialPlayers = playerManager.getAlivePlayers().length;
  if (initialPlayers === 0) {
    throw new Error('No players available to start the event');
  }

  const startedAt = Date.now();
  activeEvent = {
    id: event.id,
    startedAt,
    center,
    logPath,
    name: 'Shrinking Circle',
    initialPlayers,
    lootHistory: [],
    checkpointHistory: [],
    finalDrop: null,
  };

  circleSystem.initialize(event.id, center);
  taskSystem.start(event.id);
  taskSystem.setClaimCallback((claim) => {
    if (!activeEvent) {
      return;
    }
    activeEvent.checkpointHistory.push({
      player: claim.player.name,
      identifier: claim.player.identifier,
      immunitySeconds: claim.immunitySeconds,
      grantedPistol: claim.grantedPistol,
      timestamp: new Date().toISOString(),
    });
  });
  lootSystem.start({
    eventId: event.id,
    center,
    radius: config.startRadius,
    onLootCollected: (loot) => {
      if (!activeEvent) {
        return;
      }
      activeEvent.lootHistory.push({
        player: loot.player.name,
        identifier: loot.player.identifier,
        weapon: loot.weapon,
        crateId: loot.crateId,
        timestamp: new Date().toISOString(),
      });
    },
    onFinalDropCollected: (drop) => {
      if (!activeEvent) {
        return;
      }
      activeEvent.finalDrop = {
        player: drop.player.name,
        identifier: drop.player.identifier,
        weapon: drop.weapon,
        timestamp: new Date().toISOString(),
      };
    },
  });
  circleSystem.start();
  await updateEventState(event.id, 'LIVE');

  broadcastMessage('Shrinking Circle event has started! Stay inside the zone.');
  broadcastMessage('Loot phase active! Find your weapon before the circle closes.');
}

export async function stopEvent(reason = 'Stopped by admin'): Promise<void> {
  if (!activeEvent) {
    return;
  }

  circleSystem.stop();
  taskSystem.stop();
  lootSystem.stop();
  const { id, startedAt, initialPlayers } = activeEvent;
  const durationSeconds = Math.max(1, Math.round((Date.now() - startedAt) / 1000));
  await setEventEnded(id, new Date());

  const summary = {
    winner: null,
    durationSeconds,
    reason,
    initialPlayers,
    lootCollected: activeEvent.lootHistory,
    checkpointClaims: activeEvent.checkpointHistory,
    finalDrop: activeEvent.finalDrop,
  };
  const logPath = finalizeMatchLog(id, summary);
  await createEventResult(id, 'NONE', durationSeconds, initialPlayers, logPath);

  logEvent(id, 'STOP', `Event stopped: ${reason}`);
  playerManager.resetPlayers();
  activeEvent = null;
}

async function declareWinner(winner: playerManager.ManagedPlayer): Promise<void> {
  if (!activeEvent) {
    return;
  }

  circleSystem.stop();
  taskSystem.stop();
  lootSystem.stop();

  const { id, startedAt, initialPlayers } = activeEvent;
  const durationSeconds = Math.max(1, Math.round((Date.now() - startedAt) / 1000));

  await setEventEnded(id, new Date());
  const summary = {
    winner: winner.name,
    winnerId: winner.identifier,
    durationSeconds,
    initialPlayers,
    lootCollected: activeEvent.lootHistory,
    checkpointClaims: activeEvent.checkpointHistory,
    finalDrop: activeEvent.finalDrop,
  };
  const logPath = finalizeMatchLog(id, summary);
  await createEventResult(id, winner.identifier, durationSeconds, initialPlayers, logPath);
  logEvent(id, 'WINNER', `${winner.name} won the event`);
  winner.entity.outputChatBox?.('You are the champion!');

  broadcastMessage(`Winner: ${winner.name}`);
  playerManager.resetPlayers();
  activeEvent = null;
}

export function adjustCenter(center: CircleCenter): void {
  if (!activeEvent) {
    throw new Error('No active event');
  }

  activeEvent.center = center;
  circleSystem.setCenter(center);
  playerManager.tpAllToCenter(center);
  broadcastMessage(`Circle center moved to ${center.x.toFixed(1)}, ${center.y.toFixed(1)}`);
}

export function adjustRadius(radius: number): void {
  if (!activeEvent) {
    throw new Error('No active event');
  }

  circleSystem.setRadius(radius);
  broadcastMessage(`Circle radius set to ${radius.toFixed(1)}`);
}

function broadcastMessage(message: string): void {
  const players = mp?.players?.toArray?.() ?? [];
  players.forEach((player: RageMP.PlayerMp) => player.outputChatBox?.(`[SWT] ${message}`));
}
