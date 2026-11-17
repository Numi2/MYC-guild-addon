# MYC Radar — Murloch Yact Club

A minimal guild addon for **WoW: Forever**, interface **16001**. Type **/myc** for one compact window.

**[Download MYCRadar.zip](MYCRadar.zip?raw=true)** · **[Full instructions](MYCRadar/README.md)**

- **PvP rankings:** lifetime honorable kills, undead paladin kills recorded by MYC (including confirmed personal kills with no honor), and bounty points.
- **Guild bounty board:** full Horde names, local minimap sightings and guild reports that expire after 90 seconds. Hover for the witness and approximate observer area. Honor credit or a confirmed personal kill awards **10 points per victim per UTC day**, even without honor.
- **Shared quests and Legacy companions:** find guildmates on the same unfinished quest in your zone, or the same unfinished objective in a tracked Legacy challenge; click to whisper.
- **Guild crafters:** searchable learned recipes, item tooltips and click-to-whisper.

Guild-only synchronization. No dependencies, web services, scheduling, signup management or auction-price functionality.

## Install

Exit WoW. Extract the ZIP and put its **MYCRadar** folder in
**World of Warcraft/_forever_/Interface/AddOns/**, then start WoW and type **/myc**.
Guildmates install the same version. Replace the addon folder when upgrading; SavedVariables remain in WoW's separate WTF folder.

## What the client permits

The minimap badge is a **visible-player sighting**, not a precise enemy-position dot. MYC cannot detect hidden players. Custom kill counters accept **named honorable-kill credit, including shared kills**, or a readable standalone **PARTY_KILL** event credited to you or your pet. This second path records no-honor kills using a recent exact victim-ID observation. A corpse or someone else's killing blow alone never scores. Undead paladin classification needs recent readable race/class data. Hidden kill IDs are skipped and reported by **/myc status**; event registration does not guarantee readable delivery in live PvP.

Custom counters start when recorded by MYC. Lifetime HK totals come from WoW. Rankings and listings are last-shared guild data, not server-authoritative competition results. See the [user guide](MYCRadar/README.md) for scoring, storage and synchronization behavior.

## Source and checks

All addon source is tracked in **MYCRadar/**. The ZIP is built directly from the TOC and contains only the installable addon and its guide.

Run **lua tests/run.lua** for deterministic multi-client tests.
Run **python3 scripts/package.py** to rebuild the ZIP, and append **--check** to verify it matches the source. CI validates Lua 5.1 and 5.4 syntax, runs the tests on both versions, and checks the archive.

Automated checks cover detection, scoring, duplicate/reordered messages, guild changes, crafting, Legacy companions, report expiry and window controls. Use two guild clients to verify live synchronization after an update.
