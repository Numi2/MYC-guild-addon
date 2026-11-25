# Changelog

Versions use MAJOR.MINOR.PATCH. From 2.3.0 onward, each published version has a Git tag and a GitHub release with an installable ZIP and SHA-256 checksum.

## [2.3.0] - 2026-11-25

- **Add target:** copy a selected Horde player's full name into your bounty list with one click. Accents and other non-ASCII characters are preserved, including surnames. Works on unflagged players and corpses when WoW exposes their identity.
- Add `/myc bounty target` and `/myc bounty mouseover` for quick entry and macros.
- Paste a player hyperlink into the name field to use its full name, even when the displayed label is shortened. Duplicate listings and the five-name limit still apply.
- Keep the bounty window at its existing size; the new button uses the existing hint row.
- Publish versioned GitHub releases with changelog notes, an installable addon ZIP and checksum. Automated checks reject mismatched tags or version metadata.

Install: extract the ZIP's **MYCRadar** folder into **World of Warcraft/_forever_/Interface/AddOns/**. Existing users can replace the addon folder and `/reload`. Guildmates can update independently; the 2.x sharing protocol is unchanged.

## [2.2.0] - 2026-11-17

- Count confirmed personal or pet PvP kills without honor when a readable `PARTY_KILL` event matches a recently observed Horde player.
- Merge honor and personal kill credit for the same observed life, preserve daily bounty caps, and expose kill-signal diagnostics through `/myc status`.
- Live PvP signal readability depends on the Forever client; hidden or missing identities are skipped.

## [2.1.0] - 2026-11-16

- Add companions for shared unfinished objectives in tracked Legacy challenges.
- Show fresh, witnessed guild bounty sightings with approximate observer areas and a 90-second expiry.

## [2.0.0] - 2026-11-16

- Add compact guild PvP rankings, undead paladin counters, shared Horde bounties, minimap sightings and daily bounty points.
- Remove observed auction-price functionality; retain shared quests and guild crafters.

## [1.0.0] - 2026-11-16

- Initial installable MYC Radar distribution.
