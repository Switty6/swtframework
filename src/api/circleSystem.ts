import config from '../config/config.json';
import { CircleCenter, distance2D } from '../utils/math';
import { logEvent } from '../utils/logger';
import * as playerManager from './playerManager';

interface CircleState {
  center: CircleCenter;
  radius: number;
  running: boolean;
  lastShrinkAt: number;
}

let state: CircleState = {
  center: config.center as CircleCenter,
  radius: config.startRadius,
  running: false,
  lastShrinkAt: Date.now(),
};

let shrinkTimer: NodeJS.Timeout | null = null;
let damageTimer: NodeJS.Timeout | null = null;
let currentEventId: number | null = null;
let shrinkCallback: (radius: number, center: CircleCenter) => void = () => {};

export function setShrinkCallback(callback: (radius: number, center: CircleCenter) => void): void {
  shrinkCallback = callback;
}

export function getState(): CircleState {
  return state;
}

export function setCenter(center: CircleCenter): void {
  state = { ...state, center };
}

export function setRadius(radius: number): void {
  state = { ...state, radius };
}

export function initialize(eventId: number, center: CircleCenter): void {
  currentEventId = eventId;
  state = {
    center,
    radius: config.startRadius,
    running: false,
    lastShrinkAt: Date.now(),
  };
}

export function start(): void {
  if (state.running) {
    return;
  }

  state.running = true;
  scheduleShrink();
  startDamageLoop();
  if (currentEventId) {
    logEvent(currentEventId, 'CIRCLE_START', `Circle started at radius ${state.radius}`);
  }
}

export function stop(): void {
  state.running = false;
  if (shrinkTimer) {
    clearInterval(shrinkTimer);
    shrinkTimer = null;
  }
  if (damageTimer) {
    clearInterval(damageTimer);
    damageTimer = null;
  }
}

function scheduleShrink(): void {
  shrinkTimer = setInterval(() => {
    if (!state.running) {
      return;
    }

    const newRadius = Math.max(10, state.radius - config.shrinkStep);
    state = { ...state, radius: newRadius, lastShrinkAt: Date.now() };
    shrinkCallback(state.radius, state.center);
    if (currentEventId) {
      logEvent(currentEventId, 'CIRCLE_SHRINK', `Circle radius shrunk to ${newRadius}`);
    }
  }, config.shrinkInterval * 1000);
}

function startDamageLoop(): void {
  damageTimer = setInterval(() => {
    if (!state.running) {
      return;
    }

    const players = playerManager.getAlivePlayers();
    const now = Date.now();
    const graceMs = config.graceSeconds * 1000;

    players.forEach((managed) => {
      const player = managed.entity;
      const distance = distance2D(player.position, state.center);

      if (distance <= state.radius) {
        playerManager.updateLastInCircle(player.id);
        return;
      }

      if (playerManager.isImmune(player.id)) {
        return;
      }

      const lastInside = managed.lastInCircleAt ?? now;
      if (now - lastInside < graceMs) {
        return;
      }

      playerManager.applyDamage(player.id, config.damageOutsidePerSecond);
      player.outputChatBox?.('You are outside the circle!');
    });
  }, 1000);
}
