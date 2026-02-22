Prepare a release for HK Sounds. The user has provided the target version and some context describing the changes in their own words: $ARGUMENTS

Follow these steps:

1. Read `CHANGELOG.md` and `HKSounds.toc` to understand the current state.
2. Run `git diff` to see the current uncommitted changes. Use this as the primary source for changelog entries. Only run `git log` to look at previous commits if the user explicitly asks for it.
3. Using the diff and the user's context as input, write clear, user-facing changelog entries:
   - Plain English, concise, player-facing — no implementation details.
   - If the changes are purely bug fixes or internal improvements, consolidate them into a single bullet point (e.g. "Various bug fixes and kill detection improvements.") unless the user's message describes multiple distinct changes.
   - Only use multiple bullet points if the user's context explicitly lists separate changes.
4. Update `CHANGELOG.md` based on whether the target version already exists:
   - **If the version section already exists**: append the new entries to its existing `### Changes` list.
   - **If the version is new**: add a new section at the top of the file in this format:
     ```
     ## HK Sounds release <version>

     ### Changes

     - ...
     ```
5. Check the `## Version:` field in `HKSounds.toc`. If it doesn't match the target version, update it.
6. Summarise what was added to the changelog and whether the TOC was updated.
