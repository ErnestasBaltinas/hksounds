# HK Sounds - Claude Context

## Project Overview

**HK Sounds** is a World of Warcraft Retail addon (Interface: 120000) that plays Unreal Tournament-style announcer sounds on PvP killing blows. It also supports friendly death alerts in arenas.

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

### Sound System
- Sounds are `.ogg` files under `sounds/<folder>/<name>.ogg`
- Sound pack folder name = its string ID (e.g. `ut_classic_female`)
- Single sounds live in `sounds/single/`
- Two modes: `sound_pack` (streak/multikill logic) and `single_sound` (random from selection)

### Event Architecture
- A single `Frame` handles all events via one `eventHandler` function (routing pattern)
- `UNIT_DIED` and `PARTY_KILL` are registered/unregistered dynamically based on settings and zone

### Killing Blow Detection

`PARTY_KILL` is the primary event for detecting kills. It fires for all party member kills (not just the player's), passing `attackerGUID` and `targetGUID`. `handlePartyKill` is the entry point that routes the flow depending on the current environment.

**Open world** — GUIDs are not hidden, so detection is straightforward: `wasKilledByPlayer()` compares the attacker GUID directly against the player's GUID, and `isTargetPlayer()` inspects the target GUID prefix. If both pass, the sound plays immediately.

**Arena** — Both GUIDs are `<secret>`, so both functions fall back to heuristics that are not 100% accurate:
- `isTargetPlayer()`: assumes the target is a player if the GUID is secret and we're in a PvP instance. This is a known imprecision — it will also match totems, pets, etc.
- `wasKilledByPlayer()`: reads the total killing blow count from achievements/statistics (`GetAchievementCriteriaInfoByID(1487, 0)`) and compares it against `totalKillsCount` (saved at addon init and synced after each confirmed kill). If the count increased, we assume the player got the KB. If requirements are met, the sound plays based on settings and the current kill streak.

Currently, open world and arena killing blow logic share the same code path. The intent is to separate them in the future for cleaner, environment-specific handling.

**Battleground** — `handlePartyKill` detects the BG environment and instead of playing sound directly, calls `RequestBattlefieldScoreData()` to refresh the scoreboard, then registers `UPDATE_BATTLEFIELD_SCORE` transiently. When that event fires, `handleBattlefieldScoreUpdate()` compares the current KB count against `previousBGKillingBlows`. If the count increased, the sound plays and the saved count is updated.

### Friendly Death Alert

Tracked via `UNIT_DIED`, which is only registered when the feature is enabled and the player is in an arena. When the event fires, `handleUnitDeathInArena()` calls `getNewlyDeadFriendlyUnit()`, which loops through the player and all party members to find a unit that is dead but not yet marked as such. If found, the unit is marked dead and a random friendly death sound is played.

---

## Blizzard API Constraints

The `PARTY_KILL` event passes two arguments: `attackerGUID` and `targetGUID`. In any instanced environment — arenas, battlegrounds, dungeons, raids — Blizzard hides **both** of these as `<secret>` values (checked via `issecretvalue()`). This means we can never directly know who landed the killing blow or who died. All kill and target detection logic in this addon exists to work around this limitation.

**Current workarounds:**
- **Kill detection**: When attacker GUID is secret, infer player kill by comparing total kill count (`GetAchievementCriteriaInfoByID(1487, 0)`) before and after the event. `wasKilledByPlayer()` is a pure predicate — it only reads `totalKillsCount`. The sync (`totalKillsCount = getCurrentTotalKills()`) happens in `handlePartyKill` after the kill is confirmed.
- **Target type detection**: When target GUID is secret and we're in a PvP instance, assume the target is a player (since `PARTY_KILL` only fires for players)

Always check the latest WoW API before implementing anything:
- **WoW API docs**: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- **Blizzard source examples**: https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns

---

## Feature Scope

**In scope:**
- Sounds on player killing blows (PvP only)
- Friendly death alerts (arena only)
- Enemy death alerts in arena (upcoming — any enemy death, not just player KB)

**Out of scope:**
- Ability or cooldown tracking
- Non-PvP combat events
- Features outside of arena/BG/open-world PvP

---

## Upcoming Feature: Arena Enemy Death Alert

Community-requested. Intended to help healers who don't get killing blows.
- Trigger: any enemy unit dies in arena (not just when player gets KB)
- Scope: arena only (mirrors the friendly death alert scope)
- Stub already exists in `handleUnitDeathInArena()` in `HKSounds.lua`
- Should respect a new `enemyDeathModeEnabled` DB option (default already added in `HKSoundsDBUtils.lua`)
- Sound selection: `selectedEnemyDeathSounds` (already in DB defaults)
