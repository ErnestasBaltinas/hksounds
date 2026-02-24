# HK Sounds - Claude Context

## Project Overview

**HK Sounds** is a World of Warcraft Retail addon (Interface: 120000) that plays Unreal Tournament-style announcer sounds on PvP killing blows. It also supports friendly and enemy death alerts in arenas.

Built in Lua using the WoW addon API. Author: Dream.

---

## Development Workflow

1. Edit source files in this repo (`C:\development\addons\hk-sounds`)
2. Run `deploy.bat` - it's kept open in a terminal window; press **Enter** to deploy (uses `robocopy` to mirror files to WoW's AddOns folder, excluding `.git` and `deploy.bat`)
3. Deploy target: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\HKSounds`
4. In-game: `/reload` to apply changes

---

## File Structure

| File | Role |
|---|---|
| `HKSoundsDBUtils.lua` | Saved variable helpers, defaults, migrations |
| `HKSoundsSystem.lua` | Sound paths, sound pack/mode definitions, playback functions |
| `HKSounds.lua` | Core addon logic — event handling, kill state machine, sound dispatch |
| `HKSoundsOptions.lua` | Options panel UI |
| `HKSounds.toc` | Addon manifest (load order matches table above) |
| `sounds/` | `.ogg` audio files organized by folder (e.g. `ut_classic_female/`, `single/`) |

The addon uses the `local addonName, addon = ...` pattern. Modules attach themselves to the shared `addon` table (e.g. `addon.SoundSystem`, `addon.DBUtils`).

---

## Coding Conventions

Coming from an Angular/TypeScript background, the following conventions are used:

- **Functions**: camelCase (e.g. `handlePartyKill`, `getOptionValue`)
- **Local constants**: SCREAMING_SNAKE_CASE (e.g. `KILL_RESET_TIME`, `TRACKED_EVENTS`)
- **Module tables**: PascalCase (e.g. `SoundSystem`, `DBUtils`)
- Sections are separated with `-- ========= SECTION NAME =========` comments

---

## Architecture Notes

### Saved Variables
Stored in `HKSoundsDB` (global). Accessed via `DBUtils.getOptionValue(key)` / `DBUtils.setOptionValue(key, value)`. Defaults and migrations live in `HKSoundsDBUtils.lua`.

DB option keys:
| Key | Type | Description |
|---|---|---|
| `soundModeEnabled` | bool | Master toggle for killing blow sounds |
| `selectedSoundMode` | string | `"sound_pack"` or `"single_sound"` |
| `selectedSoundPack` | string | Folder ID of the active sound pack |
| `selectedSingleSounds` | table | `{ [soundId] = true }` set of selected single sounds |
| `friendlyDeathModeEnabled` | bool | Toggle for friendly death alert (arena only) |
| `selectedFriendlyDeathSounds` | table | `{ [soundId] = true }` set for friendly death sounds |
| `enemyDeathModeEnabled` | bool | Toggle for enemy death alert (arena only) |
| `selectedEnemyDeathSounds` | table | `{ [soundId] = true }` set for enemy death sounds |

### Sound System
- Sounds are `.ogg` files under `sounds/<folder>/<name>.ogg`
- Sound pack folder name = its string ID (e.g. `ut_classic_female`)
- Single sounds live in `sounds/single/`
- Two modes: `sound_pack` (streak/multikill logic) and `single_sound` (random from selection)
- All single-sound pools (KB, friendly death, enemy death) share the same `sounds/single/` folder

---

## Event Architecture

### Always-registered events (`TRACKED_EVENTS`)
These are registered unconditionally at startup:

| Event | Handler | Purpose |
|---|---|---|
| `PLAYER_LOGIN` | `syncTotalKills()` | Baseline kill count once achievement data is loaded |
| `PLAYER_DEAD` | `handlePlayerDead()` | Reset kill streak on player death |
| `ZONE_CHANGED_NEW_AREA` | `handleZoneChanged()` + `refreshEventRegistration()` + `syncTotalKills()` | Reset BG tracking, play start-of-match sound, re-evaluate dynamic event registration |

### Dynamically managed events
Registered/unregistered based on current zone and enabled features via `refreshEventRegistration()`. This is called at startup, on zone change, and when options are toggled.

| Event | Registered when | Handler |
|---|---|---|
| `PARTY_KILL` | `soundModeEnabled` AND (open world OR BG) | `handlePartyKill()` |
| `UNIT_DIED` | Any of: `soundModeEnabled`, `friendlyDeathModeEnabled`, `enemyDeathModeEnabled` — AND in arena | `handleUnitDeathInArena()` |
| `UPDATE_BATTLEFIELD_SCORE` | Transiently — registered per BG kill candidate, unregistered immediately on first fire | `handleBattlefieldScoreUpdate()` |

`UNIT_DIED` is spammy — it is only registered when the player is in an arena AND at least one arena feature is enabled. It is unregistered (and `deadUnitsInArena` is wiped) whenever those conditions no longer hold.

`PARTY_KILL` is not registered in arena — arena KB detection goes through `UNIT_DIED` instead.

---

## Kill Detection Flow by Environment

Detection strategy differs by zone because Blizzard hides GUIDs in instances.

```
ZONE_CHANGED_NEW_AREA
  └─ refreshEventRegistration()
       ├─ Open world / BG  → register PARTY_KILL
       └─ Arena            → register UNIT_DIED (if any feature enabled)
```

### Open World

```
PARTY_KILL (attackerGUID, targetGUID)
  └─ handlePartyKill()
       └─ handleOpenWorldPartyKill()
            ├─ attackerGUID == UnitGUID("player")?  NO → exit
            ├─ targetGUID matches "^Player%-"?       NO → exit
            └─ playKillingBlowSound()
  └─ syncTotalKills()
```

GUIDs are never secret in open world. Attacker must be the player; target must be a player unit (GUID prefix `Player-`).

### Battleground

```
PARTY_KILL
  └─ handlePartyKill()
       └─ handleBGPartyKill()
            ├─ achievement delta > 0?  NO → exit (pre-filter to avoid scoreboard spam)
            ├─ frame:RegisterEvent(UPDATE_BATTLEFIELD_SCORE)
            └─ RequestBattlefieldScoreData()

UPDATE_BATTLEFIELD_SCORE  (fires async after scoreboard refresh)
  └─ handleBattlefieldScoreUpdate()
       ├─ frame:UnregisterEvent(UPDATE_BATTLEFIELD_SCORE)
       ├─ getBGKillingBlows() > previousBGKillingBlows?
       │    YES → playKillingBlowSound()
       └─ update previousBGKillingBlows
  └─ (no syncTotalKills here — PARTY_KILL already syncs after returning)
```

GUIDs are `<secret>` in BG. The achievement delta pre-filter avoids hitting the scoreboard API for every teammate kill. The scoreboard delta (`previousBGKillingBlows`) is the authoritative check. `previousBGKillingBlows` is reset to 0 on zone change.

### Arena

Arena does not use `PARTY_KILL` at all. Instead, `UNIT_DIED` drives all arena sound features.

```
UNIT_DIED
  └─ handleUnitDeathInArena()
       ├─ handleFriendlyDeathInArena()
       │    ├─ friendlyDeathModeEnabled?  NO → exit
       │    ├─ getNewlyDeadFriendlyUnit()
       │    │    └─ loops: "player", "party1".."partyN"
       │    │         uses ArenaUtil.UnitExists() + UnitIsDead() + not deadUnitsInArena[unit]
       │    ├─ found?  NO → exit
       │    ├─ markUnitDead(unit)
       │    └─ dispatchRandomFriendlyDeathSound()
       │
       └─ handleEnemyDeathInArena()
            ├─ getNewlyDeadEnemyUnit()
            │    └─ loops: "arena1".."arenaN"  (N = GetNumArenaOpponentSpecs())
            │         uses ArenaUtil.UnitExists() + UnitIsDead() + not deadUnitsInArena[unit]
            ├─ found?  NO → exit
            ├─ markUnitDead(unit)
            ├─ achievement delta > 0 AND soundModeEnabled?
            │    YES → playKillingBlowSound()  (KB takes priority over enemy death sound)
            └─ enemyDeathModeEnabled?
                 YES → dispatchRandomEnemyDeathSound()
  └─ syncTotalKills()
```

Both functions share the same `deadUnitsInArena` table (keyed by unit token). Once a unit is marked dead it won't trigger again for the same arena session. The table is wiped on zone change.

**KB priority in arena**: When an enemy dies, the achievement counter is read immediately. If it increased, the player got the KB and `playKillingBlowSound()` fires instead of the enemy death sound. This means `soundModeEnabled` and `enemyDeathModeEnabled` can coexist — KB always wins when earned.

---

## Kill State Machine

Maintained in `HKSounds.lua` module scope:

| Variable | Purpose |
|---|---|
| `killStreak` | Total kills since last death or zone change |
| `multiKill` | Kills within a 5-second window |
| `killTime` | Timestamp of last kill (for multi-kill window) |
| `streakTimer` | `C_Timer` handle — delays streak sound when a multi-kill sound also plays |

`updateKillCounters(now)` increments both counters; `resetKillStreak()` zeroes all three on `PLAYER_DEAD` or zone change.

`handleMultiKills()` logic:
- If `multiKill > 1`: play multi-kill sound immediately on master channel, then schedule streak sound with a 2-second delay (via `C_Timer.NewTimer`)
- Otherwise: play streak sound immediately
- If no streak sound exists for the current count (capped at index 10): return early

---

## Achievement Delta — `totalKillsCount`

`totalKillsCount` is a module-level variable tracking the last-known total PvP kill count from `GetAchievementCriteriaInfoByID(1487, 0)` (return position 4 = `quantity`).

`syncTotalKills()` updates it if the new value differs and is non-nil.

**When synced:**
- `PLAYER_LOGIN` — baseline after achievement data loads
- `ZONE_CHANGED_NEW_AREA` — keeps baseline current when changing zones
- After `PARTY_KILL` fires — updates after handling so next event has fresh baseline
- After `UNIT_DIED` fires — updates after handling so the arena KB check is ready for the next death

**Important**: The achievement counter increments for any kill that grants a KB credit — including pets and totems. This means the delta approach has false positive risk in arena when non-player units die. The `PARTY_KILL` note in the CLAUDE.md about this constraint still applies.

---

## Blizzard API Constraints

The `PARTY_KILL` event passes `attackerGUID` and `targetGUID`. In any instanced environment (arena, BG, dungeon, raid) both are hidden as `<secret>` values (check: `issecretvalue()`).

**Workarounds used:**
- **Open world**: Direct GUID comparison — no workaround needed
- **BG kill detection**: Scoreboard delta (`GetBattlefieldScore`) — authoritative but async
- **BG pre-filter**: Achievement delta before hitting `RequestBattlefieldScoreData()`
- **Arena KB detection**: Achievement delta at time of `UNIT_DIED`
- **Arena target type**: `ArenaUtil.UnitExists(unitId)` — confirms unit slot is occupied
- **Arena party size**: `C_WoWLabsMatchmaking.GetPartySize()` for team size

Always check the latest WoW API before implementing anything:
- **WoW API docs**: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- **Blizzard source examples**: https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns

---

## Feature Scope

**In scope:**
- Sounds on player killing blows (open world PvP, BG, arena)
- Friendly death alerts (arena only)
- Enemy death alerts in arena (any enemy death; KB sound takes priority)

**Out of scope:**
- Ability or cooldown tracking
- Non-PvP combat events
- Features outside of arena/BG/open-world PvP
