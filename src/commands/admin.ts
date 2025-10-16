import { adjustCenter, adjustRadius, isEventRunning, startEvent, stopEvent } from '../api/eventManager';
import * as playerManager from '../api/playerManager';
import * as spectatorManager from '../api/spectatorManager';
import config from '../config/config.json';
import { CircleCenter } from '../utils/math';

export function registerAdminCommands(): void {
  mp.events.addCommand('event', async (player: RageMP.PlayerMp, fullText: string) => {
    const args = parseArgs(fullText);
    const action = args.shift()?.toLowerCase();

    try {
      switch (action) {
        case 'start':
          await startEvent();
          player.outputChatBox?.('[SWT] Event starting...');
          break;
        case 'stop':
          await stopEvent('Stopped by admin');
          player.outputChatBox?.('[SWT] Event stopped.');
          break;
        case 'tpall':
          playerManager.tpAllToCenter(config.center as CircleCenter);
          player.outputChatBox?.('[SWT] Teleported all participants to center.');
          break;
        case 'setcenter':
          if (!isEventRunning()) {
            throw new Error('No active event to adjust.');
          }
          adjustCenter(player.position as CircleCenter);
          player.outputChatBox?.('[SWT] Circle center updated.');
          break;
        case 'setradius': {
          if (!isEventRunning()) {
            throw new Error('No active event to adjust.');
          }
          const radius = parseFloat(args[0]);
          if (Number.isNaN(radius) || radius <= 0) {
            throw new Error('Invalid radius value.');
          }
          adjustRadius(radius);
          player.outputChatBox?.(`[SWT] Radius updated to ${radius}.`);
          break;
        }
        default:
          player.outputChatBox?.('[SWT] Usage: /event start|stop|tpall|setcenter|setradius <value>');
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      player.outputChatBox?.(`[SWT] Error: ${message}`);
    }
  });

  mp.events.addCommand('spec', (player: RageMP.PlayerMp, fullText: string) => {
    const args = parseArgs(fullText);
    const targetIdRaw = args[0];
    if (!targetIdRaw) {
      spectatorManager.detachSpectator(player);
      player.outputChatBox?.('[SWT] Spectator mode cleared.');
      return;
    }

    const targetId = parseInt(targetIdRaw, 10);
    if (Number.isNaN(targetId)) {
      player.outputChatBox?.('[SWT] Usage: /spec <playerId>');
      return;
    }

    const target = getPlayerById(targetId);
    if (!target) {
      player.outputChatBox?.('[SWT] Player not found.');
      return;
    }

    spectatorManager.attachToPlayer(player, target);
    player.outputChatBox?.(`[SWT] Spectating ${target.name}.`);
  });
}

function parseArgs(text: string): string[] {
  if (!text) {
    return [];
  }
  return text
    .trim()
    .split(/\s+/)
    .filter((part) => part.length > 0);
}

function getPlayerById(id: number): RageMP.PlayerMp | undefined {
  const players: RageMP.PlayerMp[] = mp?.players?.toArray?.() ?? [];
  return players.find((player) => player.id === id);
}
