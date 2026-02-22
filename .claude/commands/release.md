Prepare a release for HK Sounds. The user has provided the target version and some context describing the changes in their own words: $ARGUMENTS

Follow these steps:

1. Read `CHANGELOG.md` and `HKSounds.toc` to understand the current state.
2. Run `git log` to see commits since the last release (compare against the most recent version heading in the changelog).
3. Using the git history and the user's context as input, write clear, user-facing changelog entries. Match the tone and style of existing entries — plain English, concise, player-facing (not implementation detail focused).
4. Add a new release section at the top of `CHANGELOG.md` in this format:
   ```
   ## HK Sounds release <version>

   ### Changes

   - ...
   ```
5. Check the `## Version:` field in `HKSounds.toc`. If it doesn't match the target version, update it.
6. Summarise what was added to the changelog and whether the TOC was updated.
