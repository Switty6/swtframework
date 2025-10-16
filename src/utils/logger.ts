import { mkdirSync, writeFileSync, existsSync } from 'fs';
import { join } from 'path';

interface LogEntry {
  timestamp: string;
  type: string;
  message: string;
}

interface MatchLog {
  filePath: string;
  entries: LogEntry[];
}

const logDirectory = join(process.cwd(), 'logs');
const matchLogs = new Map<number, MatchLog>();

function ensureLogDirectory(): void {
  if (!existsSync(logDirectory)) {
    mkdirSync(logDirectory, { recursive: true });
  }
}

export function initMatchLog(eventId: number): string {
  ensureLogDirectory();
  const date = new Date();
  const name = `match-${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}${String(date.getDate()).padStart(2, '0')}-${String(date.getHours()).padStart(2, '0')}${String(date.getMinutes()).padStart(2, '0')}.json`;
  const filePath = join(logDirectory, name);
  matchLogs.set(eventId, { filePath, entries: [] });
  return filePath;
}

export function logEvent(eventId: number, type: string, message: string): void {
  const entry: LogEntry = {
    timestamp: new Date().toISOString(),
    type,
    message,
  };

  const matchLog = matchLogs.get(eventId);
  if (!matchLog) {
    // fallback for events without initialization
    initMatchLog(eventId);
    matchLogs.get(eventId)!.entries.push(entry);
    flushToDisk(eventId);
    return;
  }

  matchLog.entries.push(entry);
  flushToDisk(eventId);
}

export function finalizeMatchLog<T extends object>(eventId: number, summary: T): string | undefined {
  const matchLog = matchLogs.get(eventId);
  if (!matchLog) {
    return undefined;
  }

  const payload = {
    summary,
    entries: matchLog.entries,
  };

  writeFileSync(matchLog.filePath, JSON.stringify(payload, null, 2), 'utf-8');
  matchLogs.delete(eventId);
  return matchLog.filePath;
}

function flushToDisk(eventId: number): void {
  const matchLog = matchLogs.get(eventId);
  if (!matchLog) {
    return;
  }

  writeFileSync(matchLog.filePath, JSON.stringify({ entries: matchLog.entries }, null, 2));
}
