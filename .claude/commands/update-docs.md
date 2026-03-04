Update CLAUDE.md to reflect the current state of the codebase.

Follow these steps:

1. Read `CLAUDE.md` in full to understand what is currently documented.
2. Read all source files (`HKSounds.lua`, `HKSoundsSystem.lua`, `HKSoundsDBUtils.lua`, `HKSoundsOptions.lua`) to understand the current implementation.
3. Identify what is outdated or missing in CLAUDE.md by comparing the documentation against the actual code. Focus on:
   - Event architecture and frame setup
   - Kill detection flow per environment (open world, BG, arena)
   - Dynamically managed events table
   - Blizzard API constraints and workarounds
   - Kill state machine
   - DB option keys
   - Any functions, variables, or logic that no longer match
4. Update only the sections that are inaccurate or incomplete. Do not rewrite sections that are still correct.
5. Preserve the existing structure, formatting, and tone throughout.
6. Summarise what was changed and why.
