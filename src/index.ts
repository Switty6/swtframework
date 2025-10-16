import { registerAdminCommands } from './commands/admin';
import * as lootSystem from './api/lootSystem';
import * as playerManager from './api/playerManager';
import * as taskSystem from './api/taskSystem';

registerAdminCommands();

mp.events.add('playerDeath', (player: RageMP.PlayerMp) => {
  if (!playerManager.hasActiveEvent()) {
    return;
  }
  const managed = playerManager.getManagedPlayer(player.id);
  if (managed) {
    playerManager.eliminatePlayer(managed);
  }
});

mp.events.add('playerQuit', (player: RageMP.PlayerMp) => {
  if (!playerManager.hasActiveEvent()) {
    return;
  }
  const managed = playerManager.getManagedPlayer(player.id);
  if (managed) {
    playerManager.eliminatePlayer(managed);
  }
});

mp.events.add('swt:task:claim', (player: RageMP.PlayerMp) => {
  if (!playerManager.hasActiveEvent()) {
    return;
  }
  const result = taskSystem.claimImmunity(player.id);
  if (!result) {
    player.outputChatBox?.('[SWT] No active immunity point or it expired.');
    return;
  }
  if (result.grantedPistol) {
    player.outputChatBox?.('[SWT] Bonus pistol acquired from checkpoint!');
  }
});

mp.events.add('swt:loot:collect', (player: RageMP.PlayerMp, crateId: string) => {
  if (!playerManager.hasActiveEvent()) {
    return;
  }
  const result = lootSystem.collectCrate(player.id, crateId);
  if (!result.success) {
    player.outputChatBox?.(`[SWT] ${result.reason ?? 'Unable to collect crate.'}`);
    return;
  }
  player.outputChatBox?.(`[SWT] You equipped ${result.weapon}.`);
});

mp.events.add('swt:finaldrop:claim', (player: RageMP.PlayerMp) => {
  if (!playerManager.hasActiveEvent()) {
    return;
  }
  const result = lootSystem.collectFinalDrop(player.id);
  if (!result.success) {
    player.outputChatBox?.(`[SWT] ${result.reason ?? 'No final drop available.'}`);
    return;
  }
  player.outputChatBox?.('[SWT] RPG secured! Make it count.');
});

mp.events.addCommand('bandage', (player: RageMP.PlayerMp) => {
  const bandages = player.getVariable?.('swt:event:bandages') ?? 0;
  if (bandages <= 0) {
    player.outputChatBox?.('[SWT] You have no bandages left.');
    return;
  }
  player.setVariable?.('swt:event:bandages', bandages - 1);
  playerManager.healPlayer(player, 30);
  player.outputChatBox?.('[SWT] Bandage used. +30 HP');
});
