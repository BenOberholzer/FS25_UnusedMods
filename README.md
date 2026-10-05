# FS25 Unused Mods

Find mods in your installed mods folder that do not appear to be in use by any of your savegames. The report is generated when a savegame starts.

## Benefits

- Find unused mods across your savegames without checking each one manually.
- Prioritize larger mods for cleanup: every unused mod is listed with its file or folder name and size.
- Quickly locate the mods to review using the mods folder path shown in the report summary.
- Keep a readable log report and a separate XML report for later reference or processing.

## What counts as unused?

The mod is considered in use if any savegame has an owned vehicle, placeable, hand tool, or item from it. Script mods are also counted as used when enabled in a savegame.

Maps, mods without store items (such as script-only or texture mods), and unreadable mods are excluded from the unused list and counted as ignored in the summary.

## Where the report is written

The mod writes the details to two locations:

1. **Game log (`log.txt`)** — Search for `[UnusedMods]`. The summary includes the mods folder path and scan counts. Each unused mod line shows its name, title, file or folder name, and readable size.
2. **XML report** — `<Farming Simulator 25 user folder>/modSettings/FS25_UnusedMods/unusedMods.xml`. This structured report includes the mods folder once as `modsPath`; each mod's `path` is only its archive filename or unpacked folder name. The exact size in bytes is recorded as `sizeBytes`. For unpacked mods, the size is the combined size of their files.

If a mod's size cannot be read, the log shows `size unknown` and that XML entry omits `sizeBytes`.
