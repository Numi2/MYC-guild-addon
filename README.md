# MYC Radar — Murloch Yact Club

A minimal guild addon for **WoW: Forever**, interface **16001**. Type **/myc** for one compact window.

**[Download latest release](https://github.com/Numi2/MYC-guild-addon/releases/latest)** · **[Changelog](CHANGELOG.md)** · **[Full instructions](MYCRadar/README.md)**

- **PvP rankings:** lifetime honorable kills, undead paladin kills recorded by MYC (including confirmed personal kills with no honor), and bounty points.
- **Guild bounty board:** click **Add target** to copy a Horde player's full name, including accents, or paste a player link. See local minimap sightings and fresh guild reports that expire after 90 seconds. Hover for the witness and approximate observer area. Honor credit or a confirmed personal kill awards **10 points per victim per UTC day**, even without honor.
- **Shared quests and Legacy companions:** find guildmates on the same quest or tracked Legacy objective. One compact suggestion shows when a dungeon can advance different goals for you and guildmates.
- **Guild crafters:** searchable learned recipes, item tooltips and click-to-whisper.

Guild-only synchronization. No dependencies, web services, scheduling, signup management or auction-price functionality.

## Install

Download **MYCRadar-<version>.zip** from the latest release's **Assets**. Exit WoW, extract the ZIP and put its **MYCRadar** folder in
**World of Warcraft/_forever_/Interface/AddOns/**, then start WoW and type **/myc**.
Guildmates install the same version. Replace the addon folder when upgrading; SavedVariables remain in WoW's separate WTF folder.

## What the client permits

The minimap badge is a **visible-player sighting**, not a precise enemy-position dot. MYC cannot detect hidden players. Custom kill counters accept **named honorable-kill credit, including shared kills**, or a readable standalone **PARTY_KILL** event credited to you or your pet. This second path records no-honor kills using a recent exact victim-ID observation. A corpse or someone else's killing blow alone never scores. Undead paladin classification needs recent readable race/class data. Hidden kill IDs are skipped and reported by **/myc status**; event registration does not guarantee readable delivery in live PvP.

Custom counters start when recorded by MYC. Lifetime HK totals come from WoW. Rankings and listings are last-shared guild data, not server-authoritative competition results. See the [user guide](MYCRadar/README.md) for scoring, storage and synchronization behavior.

## Source and checks

All addon source is tracked in **MYCRadar/**. The ZIP is built directly from the TOC and contains only the installable addon and its guide.

Run **lua tests/run.lua** for deterministic multi-client tests.
Run **python3 scripts/package.py** to rebuild the repository ZIP, and append **--check** to verify it matches the source. Run **python3 scripts/release.py --check** and **python3 -m unittest discover -s tests -p 'test_*.py' -v** for release validation. CI validates Lua 5.1 and 5.4 syntax, runs the tests on both versions, and checks the archive and release metadata.

Automated checks cover detection, scoring, duplicate/reordered messages, guild changes, crafting, Legacy companions, report expiry and window controls. Use two guild clients to verify live synchronization after an update.

## Publishing a release

1. Update the version in **MYCRadar.toc**, **Core.lua**, the addon guide heading and the simulator's expected version. Add the newest dated entry at the top of **CHANGELOG.md**. Use a patch version for fixes, a minor version for compatible features, and a major version for breaking changes.
2. Rebuild **MYCRadar.zip** and pass the checks above. Merge the change into **main**.
3. On the merged commit, create an annotated tag matching the version, for example `git tag -a v2.3.0 -m 'MYC Radar v2.3.0'`, then `git push origin v2.3.0`.

The **Release addon** workflow checks that the tag belongs to main, verifies metadata and tests, then publishes a GitHub release with **MYCRadar-<version>.zip**, **SHA256SUMS.txt** and the changelog entry as release notes. Download the addon asset under **Assets**; GitHub's automatic source archives contain the development repository. For a local preview, run `python3 scripts/release.py --tag v2.3.0`; assets appear in **dist/**. Published tags and assets are kept unchanged; fixes receive a new version.
