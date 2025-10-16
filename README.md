# swtframework

A modular RageMP event framework that powers competitive mini-games similar to "MrBeast" challenges. The first implemented event is **Shrinking Circle: Melee to Bazooka**, a last-man-standing mode with phased combat that escalates from melee looting to explosive finales while tracking every highlight.

## Features
- Event lifecycle management (WAITING → LIVE → FINISHED)
- Automatic player preparation with teleport, consumables, and timed loot crates
- Shrinking circle damage system with configurable grace period and softer zone damage
- Random immunity checkpoint per shrink cycle with a chance for pistol rewards
- Final drop bazooka moment once the arena shrinks to the last 50 meters
- Spectator tools and commands
- PostgreSQL persistence via Prisma ORM
- JSON match logging to the `logs/` directory

## Project Structure
```
swtframework/
├─ src/
│  ├─ api/
│  │  ├─ eventManager.ts
│  │  ├─ playerManager.ts
│  │  ├─ spectatorManager.ts
│  │  ├─ circleSystem.ts
│  │  ├─ taskSystem.ts
│  │  └─ lootSystem.ts
│  ├─ commands/
│  │  └─ admin.ts
│  ├─ db/
│  │  ├─ client.ts
│  │  └─ eventRepo.ts
│  ├─ utils/
│  │  ├─ logger.ts
│  │  └─ math.ts
│  ├─ config/
│  │  └─ config.json
│  ├─ index.ts
│  └─ types.d.ts
├─ prisma/
│  └─ schema.prisma
├─ logs/
│  └─ match-example.json
├─ package.json
├─ tsconfig.json
└─ README.md
```

## Getting Started
1. Install dependencies:
   ```bash
   npm install
   ```
2. Configure your PostgreSQL connection by setting the `DATABASE_URL` environment variable.
3. Run database migrations:
   ```bash
   npx prisma migrate dev
   ```
4. Generate Prisma client (if not already generated via migration):
   ```bash
   npx prisma generate
   ```
5. Build or run via your RageMP Node.js runtime:
   ```bash
   npm run build
   # or for development inside RageMP server context
   npm run dev
   ```

## RageMP Integration
- Place the compiled `dist/` output (or use `ts-node-dev` for development) inside your RageMP server package.
- Ensure the `DATABASE_URL` environment variable is provided to the RageMP Node.js process.
- The entry point is `src/index.ts`, which registers commands and event listeners.

## Commands
- `/event start` — start a new Shrinking Circle round
- `/event stop` — force stop the current event
- `/event tpall` — teleport all registered participants to the configured center
- `/event setcenter` — set the circle center to the admin's position
- `/event setradius <value>` — manually adjust the circle radius
- `/spec <id>` — attach spectator camera to a player (`/spec` alone exits spectator mode)
- `/bandage` — consume the player's bandage for +30 HP (1 per event)

## Configuration
The default configuration lives in `src/config/config.json`:
```json
{
  "startRadius": 150.0,
  "shrinkStep": 25.0,
  "shrinkInterval": 60,
  "damageOutsidePerSecond": 3,
  "graceSeconds": 5,
  "taskTimeout": 20,
  "immunitySeconds": 10,
  "center": { "x": 200.0, "y": 200.0, "z": 10.0 }
}
```
Adjust values as needed for your event scales.

## Database Schema
Prisma models for events, players, and results are defined in `prisma/schema.prisma`. Run `npx prisma migrate dev` to create migrations and sync your database.

## Match Logging
Each event writes JSON logs to `logs/match-YYYYMMDD-HHMM.json` containing a summary and time-stamped entries, including who grabbed crates, checkpoints, and the final drop. An example log is provided in `logs/match-example.json` to illustrate the format.

## Example Flow
1. `/event start` — players are teleported to the arena and a 60-second loot phase spawns three melee crates inside the initial circle.
2. After the loot phase, the radius decreases every 60 seconds, spawning immunity checkpoints (20% pistol chance) while zone damage remains a tense 3 HP/sec.
3. When the circle reaches 50 meters or less, the blazing final drop appears at center with a single-use bazooka.
4. Eliminated players are moved to spectator dimension 999, where they can `/spec <id>` others.
5. The final survivor is recorded as the winner, with results, pickups, and highlights persisted to PostgreSQL and logged to JSON.

## Development Notes
- The code assumes access to RageMP server globals such as `mp`, `mp.players`, and `mp.events`.
- Utility commands and events are prefixed with `swt:` to avoid clashes.
- Extend `src/api/` with additional systems (loot drops, scoreboards, etc.) to build new mini-games on top of the same framework.

Happy hosting!
