# MYC Radar — Murloch Yact Club

A minimal, passive guild addon for World of Warcraft: Forever.

**[Download MYCRadar.zip](https://github.com/Numi2/MYC-guild-addon/raw/refs/heads/main/MYCRadar.zip)**

## Installation
1. Download `MYCRadar.zip` using the link above.
2. Exit WoW Forever.
3. Unzip and move the included `MYCRadar` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
4. Verify the file `_forever_/Interface/AddOns/MYCRadar/MYCRadar.toc` exists.
5. Launch the game. Share the same ZIP with your guild.

No setup is required. `/myc` displays status.

## Features
- **Passive quest matching:** alerts when a guildmate using the addon has the same unfinished quest in the same map area.
- **Auction price observations:** shares prices discovered during normal Auction House searches, displays recent observations in item tooltips.
- **Profession matching:** shares recipes when profession windows are opened; tooltips show known online guild crafters.

All synchronization is guild-only through WoW addon chat. No web service, automated AH queries, or protected combat automation. Guildmates need the addon installed to participate.

## Compatibility and testing
Version **1.0.0**, targeting Forever interface `16001`. Source files are included in the ZIP.

Lua syntax and offline mock tests passed (34 assertions). **Not verified in the live Forever game client.** Game-side changes may require adjustments.

Commands: `/myc`, `/myc quiet`, `/myc off`, `/myc on`, `/myc sync`.
