import { Event, EventPlayer, EventResult } from '@prisma/client';
import prisma from './client';

export async function createEventRecord(name: string): Promise<Event> {
  return prisma.event.create({
    data: {
      name,
      state: 'WAITING',
    },
  });
}

export async function updateEventState(eventId: number, state: string): Promise<Event> {
  return prisma.event.update({
    where: { id: eventId },
    data: { state },
  });
}

export async function setEventEnded(eventId: number, endedAt: Date): Promise<Event> {
  return prisma.event.update({
    where: { id: eventId },
    data: { endedAt, state: 'FINISHED' },
  });
}

export async function recordPlayerJoin(
  eventId: number,
  playerIdentifier: string,
  playerName: string,
): Promise<EventPlayer> {
  return prisma.eventPlayer.upsert({
    where: {
      eventId_playerIdentifier: {
        eventId,
        playerIdentifier,
      },
    },
    update: {
      playerName,
      alive: true,
      joinedAt: new Date(),
      leftAt: null,
    },
    create: {
      eventId,
      playerIdentifier,
      playerName,
    },
  });
}

export async function markPlayerDeath(eventId: number, playerIdentifier: string): Promise<EventPlayer> {
  return prisma.eventPlayer.update({
    where: {
      eventId_playerIdentifier: {
        eventId,
        playerIdentifier,
      },
    },
    data: {
      alive: false,
      leftAt: new Date(),
    },
  });
}

export async function updatePlayerStats(
  eventId: number,
  playerIdentifier: string,
  data: Partial<Pick<EventPlayer, 'kills' | 'damageTaken' | 'lastInCircleAt' | 'immunityUntil'>>,
): Promise<EventPlayer> {
  return prisma.eventPlayer.update({
    where: {
      eventId_playerIdentifier: {
        eventId,
        playerIdentifier,
      },
    },
    data,
  });
}

export async function listAlivePlayers(eventId: number): Promise<EventPlayer[]> {
  return prisma.eventPlayer.findMany({
    where: { eventId, alive: true },
  });
}

export async function listAllPlayers(eventId: number): Promise<EventPlayer[]> {
  return prisma.eventPlayer.findMany({
    where: { eventId },
  });
}

export async function createEventResult(
  eventId: number,
  winnerIdentifier: string,
  durationSeconds: number,
  totalPlayers: number,
  logPath?: string,
): Promise<EventResult> {
  return prisma.eventResult.create({
    data: {
      eventId,
      winnerIdentifier,
      durationSeconds,
      totalPlayers,
      logPath,
    },
  });
}
