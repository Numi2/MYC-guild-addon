# MYC Radar 2.0.0

The small in-game companion for **Murloch Yact Club**, built for **WoW: Forever**, interface **16001**.

## Install

Exit WoW. Extract the ZIP and copy the **MYCRadar** folder into
**World of Warcraft/_forever_/Interface/AddOns/**.

The file **_forever_/Interface/AddOns/MYCRadar/MYCRadar.toc** must exist.
Start WoW, enable MYC Radar in the AddOns menu and type **/myc**.
Guildmates install the same version to share data. Updating from 1.0 keeps your crafting settings and removes saved auction observations.

## Four tabs

- **PvP:** guild rankings by lifetime honorable kills, undead paladin honorable kills recorded by MYC, and bounty points. Click a guildmate to whisper. Lifetime totals come from WoW; the other counters start when MYC records them.
- **Bounties:** any member can add up to five full Horde character names, including surnames. Members can remove their own listings. Duplicate sponsors share one target and never multiply the reward. Click a name to fill the edit box.
- **Shared quests:** guildmates with the same unfinished quest in your zone. Click to whisper. Nearby matches can produce a quiet notification.
- **Crafters:** items guildmates know how to make. Open your own profession books once to share your recipes. Search by item name, ID or crafter, hover for the item tooltip, and click to whisper. Item tooltips also show recently heard guild crafters.

The slim window shows six rows at a time, with search, paging and mouse-wheel navigation.
It opens only when requested, remembers where you drag it, and closes with Escape.
Long names and recipe lists expand on hover. The bounty tab shows when you have already claimed today's reward.

## Nearby bounties

A 22-unit orange badge appears on the minimap when a listed, living hostile Horde player is **visible through your target, mouseover or an enabled enemy nameplate**. Hover for names; click for the board. It disappears when the player is no longer detected.

This is a sighting indicator. Forever does not expose unrestricted enemy positions to addons, so MYC does not draw precise enemy-location dots or discover hidden/out-of-view players. Enable enemy nameplates in WoW for passive sightings.

## Points and kill credit

A listed Horde victim awards **10 points per character per UTC day** when Blizzard emits a readable, named **honorable-kill** message and MYC has recently seen that exact character. This includes shared honorable-kill credit; it is not a killing-blow counter. Bonus honor, a dead target by itself, manual claims and duplicate chat lines award nothing. Listing a name does not spend gold or create a monetary reward.

Undead paladin credit also requires a readable race/class observation of that exact character within three minutes. MYC skips hidden or secret values. It cannot reconstruct historical victim types. It never registers the restricted combat-log events.

If the client does not provide named kill messages or their localized templates, the board explicitly reports that automatic credit is unavailable. Proximity alerts and readable lifetime HK totals still work. **/myc status** reports the available signals.

The board is a friendly guild competition: clients report their own totals over the guild channel. It is not a server-authoritative anti-cheat system. Standings show each member's last shared totals, including offline members; hover for the update age.

## Commands

| Command | Action |
| --- | --- |
| /myc | Open or close the window |
| /myc pvp, bounties, quests, crafters | Open a tab |
| /myc bounty add Full Name | Add your listing |
| /myc bounty remove Full Name | Remove your listing |
| /myc sync | Request guild refresh; at most once a minute |
| /myc quiet | Toggle popup notifications; minimap sightings remain |
| /myc off, /myc on | Disable or enable sharing and collection |
| /myc status | Show version, peers, outbox and available kill signal |

## Sharing and storage

MYC shares only over Blizzard's **GUILD addon-message channel**: unfinished quest IDs, coarse 10×10 map tiles, craftable item/recipe IDs, your own bounty names, and your own PvP totals. Guild data is separated by guild. Other members need MYC 2.x; 1.x uses a different protocol.

Quest matches and crafter availability expire from memory. Bounties and last-shared rankings persist locally; an author's next complete snapshot removes their deleted listings. Updates are authored by the member whose data changes, so a newly installed client learns an offline member's listings/totals when that member next shares. Current guild roster data filters departed members.

Messages are at most 255 bytes, paced at one every 1.5 seconds, and queued outside combat/instances. Large profession books take time to arrive. Live enemy sightings and victim identities stay on your own client; MYC never transmits an enemy location. There are no external services or dependencies.

## Verification

Automated tests simulate multiple guild clients, scoring, name detection, guild switches, transport, crafting and window controls. The source and ZIP are checked together.

**Live Forever gameplay remains unverified.** The desktop capture tool could not read the running WoW screen during development. In-game smoke check: open **/myc**, open your profession books, add a full bounty name, and use a second guild member with MYC 2.x to verify synchronization. **/console scriptErrors 1** enables WoW's Lua error dialog.
