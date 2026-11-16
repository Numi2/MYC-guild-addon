-- Deterministic multi-client simulator. No WoW installation or external libraries.
local root = arg[1] or "."
local assertions = 0
local function check(value, message)
    assertions = assertions + 1
    assert(value, message or ("assertion " .. assertions .. " failed"))
end
local function equal(a, b, message)
    check(a == b, (message or "values differ") .. ": " .. tostring(a) .. " != " .. tostring(b))
end
local methods = {}
local function widget(name)
    return setmetatable({ name = name, shown = true, scripts = {}, text = "", enabled = true }, { __index = methods })
end
for _, name in ipairs({
    "SetSize", "SetPoint", "SetFrameStrata", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetJustifyH", "SetWidth", "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag",
    "StartMoving", "StopMovingOrSizing", "SetHighlightTexture", "SetAutoFocus", "SetMaxBytes", "ClearFocus",
    "SetOwner", "SetItemByID",
    "SetWordWrap", "SetTextColor", "ClearAllPoints", "EnableMouseWheel",
}) do methods[name] = function() end end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:IsShown() return self.shown end
function methods:SetShown(shown) self.shown = shown end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:IsEnabled() return self.enabled end
function methods:GetCenter() return 280, 235 end
function methods:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:CreateFontString() return widget() end
function methods:RegisterEvent(event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then error("restricted event") end
    self.events = self.events or {}
    self.events[event] = true
end
function methods:AddLine(text) self.lines = self.lines or {}; self.lines[#self.lines + 1] = text end
function methods:AddMessage(text) self:AddLine(text) end

local SECRET = setmetatable({}, {
    __tostring = function() error("secret value converted") end,
    __concat = function() error("secret value concatenated") end,
    __lt = function() error("secret value compared") end,
    __le = function() error("secret value compared") end,
})

local function client(first, surname)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local c = {
        env = env, first = first, surname = surname, clock = 1000, epoch = 1794826800,
        guild = "Murloch Yact Club", hk = 123, units = {}, frames = {}, timers = {}, tickers = {}, sent = {},
        roster = { "Numi-Tumi", "Rhea-Tide", "Other-Sailor" }, combat = false, instance = false,
    }
    env.issecretvalue = function(value) return rawequal(value, SECRET) end
    env.time = function() return c.epoch end
    env.GetTime = function() return c.clock end
    env.date = os.date
    env.IsInGuild = function() return c.guild ~= nil end
    env.GetGuildInfo = function() return c.guild end
    env.GetRealmName = function() return "Forever" end
    env.InCombatLockdown = function() return c.combat end
    env.IsInInstance = function() return c.instance end
    env.GetNumGuildMembers = function() return #c.roster end
    env.GetGuildRosterInfo = function(i) return c.roster[i] end
    env.UnitFullName = function(unit)
        if unit == "player" then return first, surname end
        local row = c.units[unit]
        if row then return row.first, row.surname end
    end
    env.UnitName = function(unit) return env.UnitFullName(unit) end
    env.UnitExists = function(unit) return c.units[unit] ~= nil end
    env.UnitIsVisible = function(unit) return c.units[unit] and c.units[unit].visible ~= false or false end
    env.UnitIsPlayer = function(unit) return c.units[unit] and c.units[unit].player ~= false or false end
    env.UnitCanAttack = function(_, unit) return c.units[unit] and c.units[unit].hostile ~= false or false end
    env.UnitIsDeadOrGhost = function(unit) return c.units[unit] and c.units[unit].dead == true or false end
    env.UnitFactionGroup = function(unit) return c.units[unit] and c.units[unit].faction or "Alliance" end
    env.UnitClass = function(unit)
        return "Paladin", unit == "player" and "PALADIN" or (c.units[unit] and c.units[unit].class)
    end
    env.UnitRace = function(unit)
        local row = c.units[unit] or {}
        return row.race, row.race, row.raceID
    end
    env.GetPVPLifetimeStats = function() return c.hk, 0 end
    env.COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"
    env.COMBATLOG_HONORGAIN_NO_RANK = "%s dies, honorable kill (Estimated Honor Points: %d)"
    env.UIParent, env.Minimap, env.GameTooltip, env.DEFAULT_CHAT_FRAME = widget(), widget(), widget(), widget()
    env.UISpecialFrames, env.SlashCmdList = {}, {}
    env.ChatFrame_SendTell = function(name) c.whisper = name end
    env.CreateFrame = function(_, name)
        local frame = widget(name)
        c.frames[#c.frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    env.C_Timer = {
        After = function(seconds, fn) c.timers[#c.timers + 1] = { at = c.clock + seconds, fn = fn } end,
        NewTicker = function(seconds, fn) c.tickers[#c.tickers + 1] = { seconds = seconds, fn = fn } end,
    }
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function(prefix) c.prefix = prefix; return true end,
        SendAddonMessage = function(prefix, message, channel)
            if c.failSend then return 11 end
            c.sent[#c.sent + 1] = { prefix = prefix, message = message, channel = channel, at = c.clock }
            return 0
        end,
    }
    env.C_GuildInfo = { GuildRoster = function() end }
    env.C_Map = {
        GetBestMapForUnit = function() return 37 end,
        GetPlayerMapPosition = function() return { GetXY = function() return 0.35, 0.45 end } end,
    }
    c.quests = { { questID = 100, title = "A shared quest" }, { questID = 101, title = "Finished" } }
    env.C_QuestLog = {
        GetNumQuestLogEntries = function() return #c.quests end,
        GetInfo = function(i) return c.quests[i] end,
        IsComplete = function(id) return id == 101 end,
    }
    c.linked = false
    env.C_TradeSkillUI = {
        IsTradeSkillReady = function() return true end,
        IsTradeSkillLinked = function() return c.linked end,
        GetAllRecipeIDs = function() return { 1000, 1001, 1002 } end,
        GetBaseProfessionInfo = function() return { professionID = 164 } end,
        GetRecipeInfo = function(id) return { learned = id ~= 1001, disabled = false } end,
        GetRecipeSchematic = function(id) return { outputItemID = id == 1000 and 2000 or nil } end,
        GetRecipeItemLink = function(id) return id == 1002 and "|Hitem:2002|h[Armor]|h" or nil end,
    }
    env.C_Item = { GetItemNameByID = function(id) return id == 2000 and "Copper sword" or "Copper armor" end }
    env.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) c.tooltipHook = fn end }
    env.Enum = { TooltipDataType = { Item = 0 } }
    local R = {}
    for line in io.lines(root .. "/MYCRadar/MYCRadar.toc") do
        if line:match("%.lua$") then
            local chunk
            if setfenv then
                chunk = assert(loadfile(root .. "/MYCRadar/" .. line))
                setfenv(chunk, env)
            else chunk = assert(loadfile(root .. "/MYCRadar/" .. line, "t", env)) end
            chunk("MYCRadar", R)
        end
    end
    c.R = R
    function c:event(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events and frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    function c:advance(seconds)
        self.clock, self.epoch = self.clock + seconds, self.epoch + seconds
        local ready, pending = {}, {}
        for _, timer in ipairs(self.timers) do
            if timer.at <= self.clock then ready[#ready + 1] = timer else pending[#pending + 1] = timer end
        end
        self.timers = pending
        for _, timer in ipairs(ready) do timer.fn() end
    end
    function c:drain()
        local guard = 0
        while #self.R.Net.queue > 0 do
            self.R.Net:SendNext()
            self:advance(1.5)
            guard = guard + 1
            assert(guard < 1000, "outbox stuck")
        end
    end
    function c:honor(name, id)
        self:event("CHAT_MSG_COMBAT_HONOR_GAIN",
            string.format(env.COMBATLOG_HONORGAIN, name, "Knight", 12), "", "", "", "", "", 0, 0, "", 0, id)
    end
    c:event("ADDON_LOADED", "MYCRadar")
    c:event("PLAYER_LOGIN")
    return c
end

local a, b = client("Numi", "Tumi"), client("Rhea", "Tide")
local R = a.R
equal(R.version, "2.0.0")
equal(a.prefix, "MYCRadar2")
check(R.commReady, "prefix registration")
check(R.rosterReady, "guild roster loaded")
equal(R:UnitName("player"), "Numi Tumi")
equal(R:NameKey("Rhea-Tide"), R:NameKey("Rhea Tide"))
check(R:NameKey("Rhea Tide") ~= R:NameKey("Rhea Sailor"), "surnames stay distinct")
check(not R:ValidName("Injected|Hspell:123"), "reject chat markup")
check(not R:ValidName(SECRET), "secret name rejected")
check(not R:SafeNumber(SECRET, 0, 100), "secret number rejected")
check(not R:SafeNumber(0 / 0, 0, 100), "NaN rejected")
check(not R:SafeNumber(math.huge, 0, 100), "infinity rejected")
check(not R.Market, "auction module removed")
check(not R.db.guilds[R.guildKey].prices, "no auction storage")

-- One complete shared snapshot, peer authentication, fragmentation and replay.
R.Quests:Broadcast(true)
check(R.Quests.own[100] and not R.Quests.own[101], "unfinished quests only")
b.R.Quests:Broadcast(true)
b.R.Net:Receive("S|Q|100|1|1|37:3:4|100", "GUILD", "Numi-Tumi")
check(b.R.peers["numi tumi"].quests[100], "shared quest received")
local before = b.R.peers["numi tumi"].questSeen
b.R.Net:Receive("S|Q|99|1|1|37:3:4|999", "GUILD", "Numi Tumi")
check(b.R.peers["numi tumi"].quests[100], "old snapshot ignored")
equal(b.R.peers["numi tumi"].questSeen, before)
b.R.Net:Receive("S|R|101|2|2||2002:1002", "GUILD", "Numi Tumi")
check(not b.R.peers["numi tumi"].recipeSeen, "incomplete snapshot is invisible")
b.R.Net:Receive("S|R|101|1|2||2000:1000", "GUILD", "Numi Tumi")
equal(b.R.peers["numi tumi"].recipes[2002], 1002, "out-of-order parts assemble")
b.R.Net:Receive("S|R|102|1|1||2003:1003,broken", "GUILD", "Numi Tumi")
check(not b.R.peers["numi tumi"].recipes[2003], "malformed snapshot is atomic")
b.R.Net:Receive("S|R|103|1|65||2003:1003", "GUILD", "Numi Tumi")
check(not b.R.peers["numi tumi"].recipes[2003], "too many pages rejected")
b.R.Net:Receive("V|100|99999|100|100|PALADIN", "WHISPER", "Numi Tumi")
check(not b.R:GuildDB().pvp["numi tumi"], "whispers ignored")
b.R.Net:Receive("V|100|99999|100|100|PALADIN", "GUILD", "Outsider Person")
check(not b.R.peers["outsider person"], "nonmember rejected")
b.R.Net:Receive("V|100|99999|100|100|PALADIN", "GUILD", "Rhea-Tide")
check(not b.R.peers["rhea tide"], "self echo ignored")
b.R.Net:Receive(SECRET, "GUILD", "Numi Tumi")

-- Craft only your own learned outputs, including modern link fallback.
R.Professions:Scan()
equal(R.Professions:AllCrafts()[2000], 1000)
equal(R.Professions:AllCrafts()[2002], 1002)
check(not R.Professions:AllCrafts()[2001], "unlearned recipe excluded")
a.linked = true
a.env.C_TradeSkillUI.GetAllRecipeIDs = function() return { 999 } end
R.Professions:Scan()
equal(R.Professions:AllCrafts()[2000], 1000, "linked book cannot replace own recipes")
local tooltip = widget()
R.Tooltip:OnItem(tooltip, { id = 2000 })
equal(#tooltip.lines, 1, "only guild crafting tooltip line")
check(tooltip.lines[1]:find("MYC craft", 1, true), "crafting tooltip")
R.Tooltip:OnItem(tooltip, { id = SECRET })

-- Guild bounty author snapshots and duplicate sponsorship.
check(R.Bounties:Add("Grave Light"), "add bounty")
check(not R.Bounties:Add("Grave-Light"), "same identity cannot be listed twice by one author")
check(not R.Bounties:Add("Grave|Hplayer:x"), "reject malformed bounty")
equal(#R.Bounties:List(), 1)
check(R.Bounties:Receive("Rhea Tide", 200, { "Grave Light", "Bone Hammer" }))
equal(#R.Bounties:List(), 2, "duplicate sponsors share a target")
check(not R.Bounties:Remove("Bone Hammer"), "cannot remove another author's listing")
check(R.Bounties:Receive("Rhea Tide", 201, {}), "empty snapshot deletes author's listings")
check(not R.Bounties:Receive("Rhea Tide", 200, { "Bone Hammer" }), "deleted names resist stale replay")
equal(#R.Bounties:List(), 1)
for _, name in ipairs({ "Bone Hammer", "Dark Sun", "Black Sail", "Dusk Blade" }) do check(R.Bounties:Add(name)) end
check(not R.Bounties:Add("Sixth Name"), "five-listing cap")

-- Visible enemies trigger a minimap badge; friends, NPCs, corpses and secrets do not.
a.units.target = { first = "Grave", surname = "Light", faction = "Horde", class = "PALADIN", race = "Scourge", raceID = 5 }
a:event("PLAYER_TARGET_CHANGED")
check(R.Bounties.nearby["grave light"], "visible hostile bounty detected")
check(R.Bounties.badge:IsShown(), "minimap badge shown")
equal(R.Bounties.badge.label:GetText(), 1)
a.units.target.first = SECRET
a:event("PLAYER_TARGET_CHANGED")
check(not next(R.Bounties.nearby), "secret enemy identity skipped")
check(not R.Bounties.badge:IsShown(), "badge cleared on lost detection")
a.units.target.first, a.units.target.hostile = "Grave", false
a:event("PLAYER_TARGET_CHANGED")
check(not next(R.Bounties.nearby), "friendly target ignored")
a.units.target.hostile, a.units.target.player = true, false
a:event("PLAYER_TARGET_CHANGED")
check(not next(R.Bounties.nearby), "NPC ignored")
a.units.target.player, a.units.target.dead = true, true
a:event("PLAYER_TARGET_CHANGED")
check(not next(R.Bounties.nearby), "corpse is not nearby alert")
a.units.target.dead = false
a:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
a:event("PLAYER_TARGET_CHANGED")

-- Only named honorable kill credit scores; dedupe, shared credit and day limits.
equal(R.PvP:HonorVictim("You have been awarded 200 honor."), nil, "bonus honor cannot score")
equal(R.PvP:HonorVictim(SECRET), nil, "secret honor message cannot score")
equal(R.PvP:HonorVictim("Grave Light dies, honorable kill (Estimated Honor Points: 12)"), "Grave Light")
a:honor("Grave Light", 10000)
equal(R.PvP:Local().bountyKills, 1)
equal(R.PvP:Local().undeadPaladins, 1)
a:honor("Grave Light", 10000)
equal(R.PvP:Local().undeadPaladins, 1, "same chat line cannot count twice")
a:honor("Grave Light", 10001)
equal(R.PvP:Local().bountyKills, 1, "daily victim reward cap")
equal(R.PvP:Local().undeadPaladins, 2, "new honorable kill credit counts")
a:honor("Unknown Victim", 10002)
equal(R.PvP:Local().bountyKills, 1, "unobserved victim cannot score")
a:advance(181)
a:honor("Grave Light", 10003)
equal(R.PvP:Local().undeadPaladins, 2, "expired identity cannot score")
a:advance(86400)
a:event("PLAYER_TARGET_CHANGED")
a:honor("Grave Light", 10004)
equal(R.PvP:Local().bountyKills, 2, "next UTC day can score")
a.units.target.class = SECRET
a:event("PLAYER_TARGET_CHANGED")
a:honor("Grave Light", 10005)
equal(R.PvP:Local().undeadPaladins, 4, "recent readable classification survives a restricted combat read")
a.units.target.first, a.units.target.surname = "Unknown", "Paladin"
a:event("PLAYER_TARGET_CHANGED")
a:honor("Unknown Paladin", 10006)
equal(R.PvP:Local().undeadPaladins, 4, "secret class without a readable observation cannot score")
a.units.target.first, a.units.target.surname = "Grave", "Light"
a.units.target.visible = false
a:event("PLAYER_TARGET_CHANGED")
check(not next(R.Bounties.nearby), "offscreen stale target cannot show nearby")
a.units.target.visible = true
local format = R.PvP:CompileFormat("%3$d Ehre: %1$s besiegt (%2$s).")
check(format, "positional localized template compiles")
local captures = { ("12 Ehre: Grave Light besiegt (Ritter)."):match(format.pattern) }
equal(captures[format.victim], "Grave Light", "reordered victim capture")

-- Scores replace snapshots rather than adding them repeatedly.
R.PvP:Broadcast(true)
equal(R.PvP:Leaderboard("points")[1].value, 20)
equal(R.PvP:Leaderboard("lifetime")[1].value, 123)
check(R:GuildDB().pvp["numi tumi"], "local player included")
R.PvP:Receive("Rhea Tide", "V|300|456|4|3|MAGE")
R.PvP:Receive("Rhea Tide", "V|300|456|4|3|MAGE")
equal(R.PvP:Leaderboard("points")[1].value, 30, "duplicate snapshot doesn't double score")
R.PvP:Receive("Rhea Tide", "V|299|999|90|99|MAGE")
equal(R.PvP:Leaderboard("points")[1].value, 30, "old score snapshot ignored")
R.PvP:Receive("Rhea Tide", "V|301|--|99|99|MAGE")
equal(R.PvP:Leaderboard("points")[1].value, 30, "malformed score rejected")

-- Window controls, all four data views, pagination, search and bounty actions.
R.Window:Show("pvp")
check(R.Window.frame:IsShown())
equal(#R.Window:Data(), 2)
R.Window.metric = "points"
R.Window:Refresh()
R.Window.rows[1].scripts.OnClick()
equal(a.whisper, "Rhea Tide", "leaderboard click whispers member")
R.Window:Show("bounties")
equal(#R.Window:Data(), 5)
check(not R.Window.add:IsEnabled(), "empty bounty input cannot add")
R.Window.rows[1].scripts.OnClick()
check(R.Window.input:GetText() ~= "", "bounty row fills edit box")
check(R.Window.remove:IsEnabled(), "selecting your bounty enables removal")
R.Window.search:SetText("Grave")
equal(#R.Window:Data(), 1, "search filters names")
R.Window.clearSearch.scripts.OnClick()
equal(R.Window.search:GetText(), "", "clear search restores list")
R.Window.search:SetText("no such character")
check(R.Window.empty:GetText():find("No matches", 1, true), "filtered empty state explains search")
R.Window.search:SetText("")
R.Window.input:SetText("Bone Hammer")
R.Window:ChangeBounty(true)
equal(#R.Bounties:List(), 4, "remove button edits own listing")
R.Window:Show("crafters")
equal(#R.Window:Data(), 2)
R.Window.search:SetText("sword")
R.Window:Show("quests")
equal(R.Window.search:GetText(), "", "switching tabs clears prior filter")
R.Window:Toggle()
check(not R.Window.frame:IsShown(), "slash toggle closes frame")
R.Window:Toggle()
check(R.Window.frame:IsShown(), "slash toggle opens frame")

-- Wire budget and throttling, and delayed delivery through instance lockdown.
R.Net:Clear()
a.sent, a.timers = {}, {}
R.Net:QueueSnapshot("B", { "Grave Light", "Black Sail" }, "", true)
R.Net:Queue("H", "H")
R.Net:SendNext()
equal(#a.sent, 1)
R.Net:SendNext()
equal(#a.sent, 1, "send rate limited")
a:advance(1.5)
a.instance = true
R.Net:SendNext()
equal(#a.sent, 1, "no sends in instances")
check(#R.Net.queue > 0, "instance keeps pending data")
a.instance, a.combat = false, true
R.Net:SendNext()
equal(#a.sent, 1, "no sends in combat")
a.combat = false
a:drain()
equal(#a.sent, 2, "pending message sent outside lockdown")
for _, packet in ipairs(a.sent) do
    check(#packet.message <= 255, "wire payload within limit")
    equal(packet.channel, "GUILD", "only guild traffic")
end
R.Net:Clear()
local many = {}
for i = 1, 600 do many[#many + 1] = (20000 + i) .. ":" .. (30000 + i) end
check(R.Net:QueueSnapshot("R", many, "", false), "large profession book fits")
check(#R.Net.queue > 30, "supports more than 30 recipe pages")
for _, packet in ipairs(R.Net.queue) do check(#packet.text <= 255, "fragment fits payload") end
R.Net:QueueSnapshot("R", { "2000:1000" }, "", false)
equal(#R.Net.queue, 1, "shorter snapshot removes obsolete tail")
a.failSend = true
for _ = 1, 6 do a:advance(6); R.Net:SendNext() end
equal(#R.Net.queue, 0, "retries bounded")
equal(R.Net.errors, 1)
a.failSend = false

-- Full source -> outbox -> guild transport -> second client's persisted board.
R.Net:Clear()
a.sent, a.timers = {}, {}
R:Sync(false)
a:drain()
for _, packet in ipairs(a.sent) do
    b.R.Net:Receive(packet.message, packet.channel, "Numi-Tumi")
end
check(b.R.Bounties:IsListed("grave light"), "bounty board round-trips over the wire")
check(not b.R.Bounties:IsListed("bone hammer"), "removed bounty stays removed on a fresh complete snapshot")
equal(b.R:GuildDB().pvp["numi tumi"].bountyKills, 2, "PvP score round-trips")
equal(b.R.peers["numi tumi"].recipes[2000], 1000, "crafting snapshot round-trips")
check(b.R.peers["numi tumi"].quests[100], "quest snapshot round-trips")
local utf8name = string.rep("Æ", 20) .. " " .. string.rep("ø", 18)
check(R:ValidName(utf8name), "UTF-8 names accepted within the byte budget")
R.Net:Clear()
check(R.Net:QueueSnapshot("B", { utf8name, "Grave Light", "Dusk Blade" }, "", true), "UTF-8 bounty snapshot fits")
for _, packet in ipairs(R.Net.queue) do check(#packet.text <= 255, "UTF-8 packet stays within byte limit") end

-- Disabling and guild changes clear detection, transport and identity state.
a.env.SlashCmdList.MYCRADAR("off")
check(not R:IsEnabled())
check(not R.Bounties.badge:IsShown())
R.Net:Queue("H")
equal(#R.Net.queue, 0, "disabled cannot enqueue")
a.env.SlashCmdList.MYCRADAR("on")
check(R:IsEnabled())
a.guild = "Another Guild"
a:event("PLAYER_GUILD_UPDATE")
equal(#R.Bounties:List(), 0, "bounties scoped to guild")
check(not next(R.peers), "peers cleared on guild switch")
check(not next(R.PvP.enemies), "victim identity cleared on guild switch")
equal(#R.Net.queue, 0, "no prior guild packets survive")
a.guild = nil
a:event("PLAYER_GUILD_UPDATE")
equal(R.guildKey, nil, "guild leave clears active guild")
check(not R:GuildDB(), "unguilded cannot access previous guild")
check(not R.Bounties:Add("Enemy Person"), "unguilded cannot add bounties")

-- Migration removes retired auction samples in every historical guild.
local c = client("Other", "Sailor")
c.env.MYCRadarDB.guilds["Old Guild@Forever"] = { prices = { [123] = 999 } }
c.R:InitializeDB()
check(not c.R.db.guilds["Old Guild@Forever"].prices, "legacy auction data removed")
c.env.COMBATLOG_HONORGAIN, c.env.COMBATLOG_HONORGAIN_NO_RANK = nil, nil
equal(#c.R.PvP:HonorFormats(), 0, "unsupported kill parser has no fabricated fallback")
c.R.Window:Show("bounties")
check(c.R.Window.footer:GetText():find("unavailable", 1, true), "unavailable credit explained in UI")
c.hk = SECRET
c.R.PvP:Broadcast(true)
equal(c.R.PvP:Local().lifetime, 123, "secret lifetime stats cannot replace last readable value")

print("PASS: " .. assertions .. " assertions")
