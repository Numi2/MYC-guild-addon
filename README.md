# MYC Radar — Murloch Yact Club

A minimal guild addon for **WoW: Forever**, interface **16001**. Type **/myc** for one compact window.

**[Download MYCRadar.zip](MYCRadar.zip?raw=true)** · **[Full instructions](MYCRadar/README.md)**

- **PvP rankings:** lifetime honorable kills, undead paladin honorable kills recorded by MYC, and bounty points.
- **Guild bounty board:** members add full Horde character names. A minimap badge flags a listed player detected on a visible target, mouseover or nameplate. Named honorable-kill credit awards **10 points per victim per UTC day**.
- **Shared quests:** find guildmates on the same unfinished quest in your zone; click to whisper.
- **Guild crafters:** searchable learned recipes, item tooltips and click-to-whisper.

Guild-only synchronization. No dependencies, web services, scheduling, signup management or auction-price functionality.

## Install

Exit WoW. Extract the ZIP and put its **MYCRadar** folder in
**World of Warcraft/_forever_/Interface/AddOns/**, then start WoW and type **/myc**.
Guildmates install the same version. Replace the addon folder when upgrading; SavedVariables remain in WoW's separate WTF folder.

## What the client permits

The minimap badge is a **visible-player sighting**, not a precise enemy-position dot. MYC cannot detect hidden players. Kill categories use **honorable-kill credit, including shared kills**, rather than final blows. Undead paladin and bounty credit require a readable named honor message and recent readable identity data; unsupported signals are reported in the window and **/myc status**.

Custom counters start when recorded by MYC. Lifetime HK totals come from WoW. Rankings and listings are last-shared guild data, not server-authoritative competition results. See the [user guide](MYCRadar/README.md) for scoring, storage and synchronization behavior.

## Source and checks

All addon source is tracked in **MYCRadar/**. The ZIP is built directly from the TOC and contains only the installable addon and its guide.

Run **lua tests/run.lua** for deterministic multi-client tests.
Run **python3 scripts/package.py** to rebuild the ZIP, and append **--check** to verify it matches the source. CI validates Lua 5.1 and 5.4 syntax, runs the tests on both versions, and checks the archive.

**Live Forever gameplay remains unverified:** desktop capture could not read the running game screen. Automated checks cover detection, scoring, duplicate/reordered messages, guild changes, crafting and window controls; they do not establish live-client behavior.
