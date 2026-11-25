# MYC Radar 2.4.0

The small in-game companion for **Murloch Yact Club**, built for **WoW: Forever**, interface **16001**.

## Install

Exit WoW. Extract the ZIP and copy the **MYCRadar** folder into
**World of Warcraft/_forever_/Interface/AddOns/**.

The file **_forever_/Interface/AddOns/MYCRadar/MYCRadar.toc** must exist.
Start WoW, enable MYC Radar in the AddOns menu and type **/myc**.
Guildmates install the same version to share data. Updating from 1.0 keeps your crafting settings and removes saved auction observations.

## Four tabs

- **PvP:** guild rankings by lifetime honorable kills, undead paladin kills recorded by MYC, and bounty points. Custom kills include confirmed personal kills with no honor. Click a guildmate to whisper. Lifetime totals come from WoW; the other counters start when MYC records them.
- **Bounties:** select a Horde player and click **Add target** to copy their full name exactly, including accents and surname. You can also paste a player link or type a full name in the field below. Each member can add up to five names and remove their own listings. Duplicate sponsors share one target and never multiply the reward. Click a listed name to fill the edit box.
- **Shared quests:** see guildmates with the same unfinished quest in your zone. When one dungeon can advance different goals for you and a guildmate, the first row names the dungeon and how many guildmates benefit. Hover to see everyone's quests and Legacy objectives. The separate **Legacy goals** view shows guildmates who track the same unfinished challenge objective.
- **Crafters:** items guildmates know how to make. Open your own profession books once to share your recipes. Search by item name, ID or crafter, hover for the item tooltip, and click to whisper. Item tooltips also show recently heard guild crafters.

The slim window shows six rows at a time, with search, paging and mouse-wheel navigation.
It opens only when requested, remembers where you drag it, and closes with Escape.
Long names and recipe lists expand on hover. The bounty tab shows when you have already claimed today's reward.

**Quick bounty entry:** `/myc bounty target` copies your selected Horde player; `/myc bounty mouseover` copies the Horde player under your cursor. Both can be used in macros and work on unflagged players or corpses when WoW exposes the name. Hidden identities, Alliance players and NPCs cannot be copied. A pasted player hyperlink uses its full name, even when the chat label shows only a first name. Accents are preserved through saving and guild sharing.

## Nearby bounties

A 22-unit orange badge appears on the minimap when a listed, living hostile Horde player is **visible through your target, mouseover or an enabled enemy nameplate**. Hover for names; click for the board. It disappears when the player is no longer detected.

This is a sighting indicator. Forever does not expose unrestricted enemy positions to addons, so MYC does not draw precise enemy-location dots or discover hidden/out-of-view players. Enable enemy nameplates in WoW for passive sightings.

The bounty board also shows **fresh guild sightings**. A member who directly sees a listed, living hostile Horde player shares a short report with their name as witness, the time of observation and their own coarse map area. The row shows the report's age and zone; hover for the witness, approximate 10×10 observer map grid and reward details. These reports expire **90 seconds after the observation**, even if delivery was delayed. A currently visible target can refresh its report at most once every 30 seconds.

A remote report never lights your minimap badge or awards points. The target may have moved, or the witness may be on another layer. Reports are kept only in memory, are never forwarded, and clear when MYC is disabled or you change guild. Instance observations are not shared.

## Legacy companions

Open WoW's Legacy challenges, expand a challenge you want to work on and enable its tracking checkbox. Then open **/myc quests → Legacy goals**. Guildmates using MYC 2.1 who track the same challenge appear when you both have an unfinished objective in common, wherever they are in the world. Different unfinished objectives in the same challenge do not create a match.

Only tracked challenges are shared: at most ten challenges and 128 unfinished objectives. Completing an objective or untracking a challenge removes it from your next snapshot. Matches expire after seven minutes without an update. The counter shows tracked Legacy challenges; the list shows actual companions, and search includes challenge and objective names.

Legacy points are account-wide. A character can still have an unfinished objective after the account earned its reward; MYC compares character progress and does not promise additional Legacy points.

The dungeon suggestion combines current quest logs and tracked Legacy goals across zones. It covers **The Deadmines**, **City of Dalaran**, and **The Drowned City**, and prefers the dungeon that helps the most people. Players need a recent guild update to appear.

## Points and kill credit

A listed Horde victim awards **10 points per character per UTC day** through either of these signals:

- A readable, named **honorable-kill** message with a recent observation of that exact character. This includes shared honor credit.
- A readable standalone **PARTY_KILL** event identifying you or your current pet as the killer, matched to a recently observed exact player GUID. **No honor is required.** A teammate's killing blow alone does not score for you.

Both paths also count undead paladins with a readable race/class observation within three minutes. MYC merges the two signals for the same observed life within ten seconds, so a kill followed by honor credit does not count twice. A witnessed resurrection starts a new life. Repeated native kill events within that window are ignored. WoW's lifetime HK counter is never increased by MYC.

Bonus honor, a corpse or bare death event, remote sightings, manual claims and duplicate chat lines award nothing. Listing a name does not spend gold or create a monetary reward.

MYC skips hidden or secret values. It cannot reconstruct missed historical kills. It never registers the restricted combat-log events. The standalone kill event is documented by Forever's native API, but actual PvP event delivery and GUID readability still need a live-client check; synthetic tests do not establish that every no-honor kill is observable.

If neither kill signal can register, the board reports that automatic credit is unavailable. Proximity alerts and readable lifetime HK totals still work. **/myc status** reports named honor support, personal event registration, received events, hidden IDs, unmapped victims and events that added a custom score. These session counters reset on disable or guild change. For a missed no-honor kill, run it immediately afterward: hidden or missing events cannot be inferred from a visible corpse.

The board is a friendly guild competition: clients report their own totals over the guild channel. It is not a server-authoritative anti-cheat system. Standings show each member's last shared totals, including offline members; hover for the update age.

## Commands

| Command | Action |
| --- | --- |
| /myc | Open or close the window |
| /myc pvp, bounties, quests, crafters | Open a tab |
| /myc bounty target | Add the selected Horde player's full name |
| /myc bounty mouseover | Add the Horde player under your cursor |
| /myc bounty add Full Name | Add your listing |
| /myc bounty remove Full Name | Remove your listing |
| /myc sync | Request guild refresh; at most once a minute |
| /myc quiet | Toggle popup notifications; minimap sightings remain |
| /myc off, /myc on | Disable or enable sharing and collection |
| /myc status | Show version, peers, outbox and available kill signal |

## Sharing and storage

MYC shares only over Blizzard's **GUILD addon-message channel**: unfinished quest IDs, coarse 10×10 observer map tiles, craftable item/recipe IDs, your own bounty names, your own PvP totals, tracked Legacy objective IDs/progress, and short-lived witnessed bounty reports. Guild data is separated by guild. Members need MYC 2.2 to collect personal no-honor kills, and 2.1 or later for Legacy companions and fresh guild sightings. Older 2.x clients display the totals but collect only the signals their own version supports; 1.x uses a different protocol. Victim GUIDs stay in local session memory and are never transmitted.

Quest matches and crafter availability expire from memory. Bounties and last-shared rankings persist locally; an author's next complete snapshot removes their deleted listings. Updates are authored by the member whose data changes, so a newly installed client learns an offline member's listings/totals when that member next shares. Current guild roster data filters departed members.

If Forever leaves the realm name blank, MYC reopens the character's prior guild save when there is one clear match. It combines activity from before and after the realm change where the timestamps show distinct periods. If several previous realms fit the same guild name, their records stay separate.

Messages are at most 255 bytes, paced at one every 1.5 seconds, and queued outside combat/instances. Large profession books take time to arrive. Bounty reports share the listed name and witness's approximate area; exact enemy coordinates and race/class observations are never transmitted. There are no external services or dependencies.

## Verification

Automated tests simulate multiple guild clients, no-honor and pet kill credit, honor/kill event ordering, duplicate signals, observed resurrections, secret and stale IDs, daily bounty caps, name detection, guild switches, transport, crafting, Legacy objective matching, sighting expiry/replay and window controls. The source and ZIP are checked together.

In-game smoke check: with two guild members on MYC 2.3, select a Horde player with accents in their name, open **Bounties** and click **Add target**. Confirm the full name and surname appear on both boards without retyping. Try the target/mouseover commands and a pasted player link; repeated entry must not create duplicates. A member directly observing that living hostile player should produce a report on the other member's board, which expires after 90 seconds without a fresh observation. Track the same unfinished Legacy challenge and check **Quests → Legacy goals**. For kill credit, observe a living undead paladin, confirm a personal kill with no honor, then check the custom counter and **/myc status**. Repeat with honor and check that one death adds only one kill; killing a listed victim twice in a day must award only ten points. **/console scriptErrors 1** enables WoW's Lua error dialog.
