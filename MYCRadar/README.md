# MYC Radar 2.1.0

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
- **Shared quests:** switch between **Shared quests** and **Legacy goals** within this tab. Quest matches show guildmates on the same unfinished quest in your zone. Legacy matches show guildmates who still need the same objective in a challenge you both track in WoW's Legacy window. Hover for both characters' progress; click to whisper.
- **Crafters:** items guildmates know how to make. Open your own profession books once to share your recipes. Search by item name, ID or crafter, hover for the item tooltip, and click to whisper. Item tooltips also show recently heard guild crafters.

The slim window shows six rows at a time, with search, paging and mouse-wheel navigation.
It opens only when requested, remembers where you drag it, and closes with Escape.
Long names and recipe lists expand on hover. The bounty tab shows when you have already claimed today's reward.

## Nearby bounties

A 22-unit orange badge appears on the minimap when a listed, living hostile Horde player is **visible through your target, mouseover or an enabled enemy nameplate**. Hover for names; click for the board. It disappears when the player is no longer detected.

This is a sighting indicator. Forever does not expose unrestricted enemy positions to addons, so MYC does not draw precise enemy-location dots or discover hidden/out-of-view players. Enable enemy nameplates in WoW for passive sightings.

The bounty board also shows **fresh guild sightings**. A member who directly sees a listed, living hostile Horde player shares a short report with their name as witness, the time of observation and their own coarse map area. The row shows the report's age and zone; hover for the witness, approximate 10×10 observer map grid and reward details. These reports expire **90 seconds after the observation**, even if delivery was delayed. A currently visible target can refresh its report at most once every 30 seconds.

A remote report never lights your minimap badge or awards points. The target may have moved, or the witness may be on another layer. Reports are kept only in memory, are never forwarded, and clear when MYC is disabled or you change guild. Instance observations are not shared.

## Legacy companions

Open WoW's Legacy challenges, expand a challenge you want to work on and enable its tracking checkbox. Then open **/myc quests → Legacy goals**. Guildmates using MYC 2.1 who track the same challenge appear when you both have an unfinished objective in common, wherever they are in the world. Different unfinished objectives in the same challenge do not create a match.

Only tracked challenges are shared: at most ten challenges and 128 unfinished objectives. Completing an objective or untracking a challenge removes it from your next snapshot. Matches expire after seven minutes without an update. The counter shows tracked Legacy challenges; the list shows actual companions, and search includes challenge and objective names.

Legacy points are account-wide. A character can still have an unfinished objective after the account earned its reward; MYC compares character progress and does not promise additional Legacy points.

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

MYC shares only over Blizzard's **GUILD addon-message channel**: unfinished quest IDs, coarse 10×10 observer map tiles, craftable item/recipe IDs, your own bounty names, your own PvP totals, tracked Legacy objective IDs/progress, and short-lived witnessed bounty reports. Guild data is separated by guild. Other members need MYC 2.1 for Legacy companions and fresh guild sightings. Core 2.0 features remain compatible; 1.x uses a different protocol.

Quest matches and crafter availability expire from memory. Bounties and last-shared rankings persist locally; an author's next complete snapshot removes their deleted listings. Updates are authored by the member whose data changes, so a newly installed client learns an offline member's listings/totals when that member next shares. Current guild roster data filters departed members.

Messages are at most 255 bytes, paced at one every 1.5 seconds, and queued outside combat/instances. Large profession books take time to arrive. Bounty reports share the listed name and witness's approximate area; exact enemy coordinates and race/class observations are never transmitted. There are no external services or dependencies.

## Verification

Automated tests simulate multiple guild clients, scoring, name detection, guild switches, transport, crafting, Legacy objective matching, sighting expiry/replay and window controls. The source and ZIP are checked together.

In-game smoke check: with two guild members on MYC 2.1, track the same unfinished Legacy challenge and open **Quests → Legacy goals**. Add a full bounty name; a member directly observing that player should produce a report on the other member's board, which expires after 90 seconds without a fresh observation. **/console scriptErrors 1** enables WoW's Lua error dialog.
