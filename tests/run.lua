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
function methods:SetSize(width, height) self.width, self.height = width, height end
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
    env.time = function() return math.floor(c.epoch) end
    env.GetServerTime = function() return math.floor(c.epoch) end
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
    c.guid = "Player-1-00000001"
    env.UnitGUID = function(unit)
        if unit == "player" then return c.guid end
        if unit == "pet" then return c.petGUID end
        return c.units[unit] and c.units[unit].guid
    end
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
        GetMapInfo = function(id) return { name = id == 37 and "Elwynn Forest" or "Hillsbrad Foothills" } end,
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
    env.Enum = { TooltipDataType = { Item = 0 }, ContentTrackingType = { Achievement = 2 } }
    env.Constants = { LegacyConsts = { LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225 } }
    c.tracked = { 900 }
    c.legacy = {
        [900] = { name = "Dungeon companions", accountDone = true, earned = false, points = 10,
            criteria = {
                { name = "Defeat Baron Rivendare", quantity = 0, required = 1, done = false },
                { name = "Defeat Gandling", quantity = 1, required = 1, done = true },
            } },
        [901] = { name = "Profession milestone", points = 5,
            criteria = { { name = "Reach 150 skill", quantity = 100, required = 150, done = false } } },
        [902] = { name = "Ordinary achievement", points = 0, criteria = {} },
    }
    env.C_ContentTracking = { GetTrackedIDs = function() return c.tracked end }
    env.C_Traits = { GetTraitCurrencyForAchievement = function(currency, id)
        assert(currency == 4225, "Legacy currency")
        return c.legacy[id] and c.legacy[id].points
    end }
    env.GetAchievementInfo = function(id)
        local row = c.legacy[id]
        if row then return id, row.name, 10, row.accountDone or false, nil, nil, nil, "", 0, 0, "", false, row.earned or false end
    end
    env.GetAchievementNumCriteria = function(id) return #(c.legacy[id] and c.legacy[id].criteria or {}) end
    env.GetAchievementCriteriaInfo = function(id, i)
        local row = c.legacy[id].criteria[i]
        return row.name, 0, row.done, row.quantity, row.required, nil, nil, row.asset
    end
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
equal(R.version, "2.4.0")
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
check(b.R.peers["numi tumi"].legacy["900:1"], "Legacy snapshot round-trips")
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
check(not next(R.Legacy.own), "Legacy goals cleared on guild switch")
check(not next(R.Bounties.sightings), "sightings cleared on guild switch")
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
check(not c.R.Window.footer:GetText():find("unavailable", 1, true), "personal kill credit remains when honor parser is absent")
c.R.failedEvents.PARTY_KILL = true
c.R.Window:Refresh()
check(c.R.Window.footer:GetText():find("unavailable", 1, true), "unavailable credit explained in UI")
c.hk = SECRET
c.R.PvP:Broadcast(true)
equal(c.R.PvP:Local().lifetime, 123, "secret lifetime stats cannot replace last readable value")

-- Forever's realm hotfix can leave both the original and a new blank-key bucket.
local migration = client("Numi", "Tumi")
local M = migration.R
local previous, blank = M.guildKey, migration.guild .. "@"
local old = M:CharGuildDB()
local today = os.date("!%Y-%m-%d", migration.epoch)
old.pvp = { since = migration.epoch - 100, undeadPaladins = 4, bountyKills = 2,
    lifetime = 100, claimed = { ["old target"] = today } }
old.bounties = { ["old target"] = "Old Target" }
old.professions[164] = { updated = 10, crafts = { [2000] = 1000 } }
M:GuildDB().pvp["numi tumi"] = { revision = 10, updated = migration.epoch - 50 }
M:GuildDB().bounties["rhea tide"] = { revision = 10, targets = { ["old target"] = "Old Target" } }
M.charDB.guilds[blank] = {
    pvp = { since = migration.epoch - 40, undeadPaladins = 12, bountyKills = 2,
        lifetime = 120, claimed = { ["old target"] = today, ["new target"] = today } },
    bounties = { ["new target"] = "New Target" },
    professions = { [164] = { updated = 20, crafts = { [2001] = 1001 } } },
}
M.db.guilds[blank] = {
    pvp = { ["rhea tide"] = { revision = 20, undeadPaladins = 5 } },
    bounties = { ["rhea tide"] = { revision = 20, targets = {} } },
}
migration.env.GetRealmName = function() return "" end
M:InitializeDB()
equal(M.guildKey, previous, "blank realm reopens this character's established guild")
equal(M.PvP:Local().undeadPaladins, 16, "recover both nonoverlapping kill totals")
equal(M.PvP:Local().bountyKills, 3, "do not double-count a known same-day claim")
equal(M.PvP:Local().claimed["new target"], today, "today's claims remain in force")
equal(M.Bounties:Own()["old target"], "Old Target")
equal(M.Bounties:Own()["new target"], "New Target")
equal(M.Professions:AllCrafts()[2001], 1001, "keep most recent profession scan")
equal(M:GuildDB().pvp["rhea tide"].undeadPaladins, 5, "carry forward newer guild scores")
check(not next(M:GuildDB().bounties["rhea tide"].targets), "latest guild snapshot preserves a deletion")
check(M.Bounties:Remove("Old Target"))
M:InitializeDB()
equal(M.PvP:Local().undeadPaladins, 16, "repeated reload cannot count the split totals again")
check(not M.Bounties:Own()["old target"], "repeated reload cannot revive a removed bounty")
equal(M.charDB.guilds[blank].pvp.undeadPaladins, 12, "original blank bucket remains available")
migration.guild = "Different Guild"
M.charDB.guilds[migration.guild .. "@One"] = { pvp = { undeadPaladins = 1 } }
M.charDB.guilds[migration.guild .. "@Two"] = { pvp = { undeadPaladins = 2 } }
equal(M:UpdateGuild(), migration.guild .. "@", "ambiguous historical realms stay separate")
equal(M.PvP:Local().undeadPaladins, 0, "ambiguous realm does not import other guild data")

-- Selected Legacy goals match the same unfinished objective, not merely a challenge.
local d, e = client("Numi", "Tumi"), client("Rhea", "Tide")
local D, E = d.R, e.R
D.Legacy:Broadcast(true)
E.Legacy:Broadcast(true)
check(D.Legacy.own["900:1"], "account-wide completion does not hide character progress")
check(not D.Legacy.own["900:2"], "completed criterion excluded")
d:drain()
for _, packet in ipairs(d.sent) do E.Net:Receive(packet.message, packet.channel, "Numi-Tumi") end
equal(#E.Legacy:Matches(), 1, "matching unfinished Legacy objective")
E.Window:Show("quests")
E.Window.questViews.legacy.scripts.OnClick()
equal(#E.Window:Data(), 1, "Legacy lives inside quest tab")
equal(E.Window.rows[1].data.left, "Defeat Baron Rivendare")
equal(E.Window.frame.width, 390, "Legacy preserves compact window width")
equal(E.Window.frame.height, 340, "Legacy preserves compact window height")
check(E.Window.rows[1].data.detail:find("You: 0/1", 1, true), "tooltip includes progress")
E.Window.rows[1].scripts.OnClick()
equal(e.whisper, "Numi-Tumi", "Legacy row whispers the witness")
E.Window.search:SetText("Dungeon companions")
equal(#E.Window:Data(), 1, "search matches the parent challenge name")
E.Window.search:SetText("")
local savedSeen = E.peers["numi tumi"].legacySeen
E.peers["numi tumi"].legacySeen = E:Clock() - 420
equal(#E.Legacy:Matches(), 0, "stale companions expire")
E.peers["numi tumi"].legacySeen = savedSeen
e.legacy[900].criteria[1].done = true
E.Legacy:Broadcast(false)
equal(#E.Legacy:Matches(), 0, "finishing local goal removes match immediately")
e.legacy[900].criteria[1].done, e.legacy[900].criteria[2].done = true, false
e.legacy[900].criteria[2].quantity = 0
E.Legacy:Broadcast(false)
equal(#E.Legacy:Matches(), 0, "different unfinished criterion is not a match")
e.legacy[900].earned = true
E.Legacy:Broadcast(false)
check(not next(E.Legacy.own), "character-earned challenge excluded")
e.legacy[900].earned = false
e.tracked = { 901, 902, 901 }
E.Legacy:Broadcast(false)
equal(E.Legacy.tracked, 1, "only unique Legacy challenges count")
check(E.Legacy.own["901:1"], "selected profession goal shared")
check(not E.Legacy.own["902:0"], "ordinary achievement excluded")
e.legacy[901].criteria[1].quantity = SECRET
E.Legacy:Broadcast(false)
check(not next(E.Legacy.own), "secret progress excluded")
e.legacy[901].criteria[1].quantity = 100
e.tracked = {}
e.timers = {}
e:advance(21)
E.Net:Clear()
E.Legacy:Broadcast(true)
equal(E.Net.queue[1].text:sub(-1), "|", "untracking emits empty snapshot")
local peer = E.peers["numi tumi"]
local revision = peer.revisions.L + 100
E.Net:Receive(string.format("S|L|%.0f|1|1||900:1:0:1,broken", revision), "GUILD", "Numi-Tumi")
check(peer.legacy["900:1"], "malformed Legacy snapshot is atomic")
E.Net:Receive(string.format("S|L|%.0f|1|1||900:1:1:1", revision), "GUILD", "Numi-Tumi")
check(peer.legacy["900:1"], "completed peer progress rejected")
E.Net:Receive(string.format("S|L|%.0f|1|1||", revision), "GUILD", "Numi-Tumi")
check(not next(peer.legacy), "empty snapshot clears removed goals")
E.Net:Receive(string.format("S|L|%.0f|1|1||900:1:0:1", revision - 1), "GUILD", "Numi-Tumi")
check(not next(peer.legacy), "stale Legacy snapshot cannot revive goals")
e.env.C_ContentTracking = nil
E.Legacy:Broadcast(false)
check(not next(E.Legacy.own), "missing Legacy API degrades safely")
E.Window:Refresh()
check(E.Window.empty:GetText():find("unavailable", 1, true), "unsupported Legacy explained")

-- Fresh witnessed reports travel from actual detection; remote reports never light the badge.
d, e = client("Numi", "Tumi"), client("Rhea", "Tide")
D, E = d.R, e.R
check(D.Bounties:Add("Grave Light"))
d:drain()
for _, packet in ipairs(d.sent) do E.Net:Receive(packet.message, packet.channel, "Numi-Tumi") end
d.sent, d.timers = {}, {}
d.units.target = { first = "Grave", surname = "Light", faction = "Horde", class = "PALADIN", raceID = 5 }
d:event("PLAYER_TARGET_CHANGED")
local report
for _, packet in ipairs(D.Net.queue) do if packet.text:sub(1, 2) == "T|" then report = packet.text end end
check(report and #report <= 255, "observed bounty creates bounded report")
local queueSize = #D.Net.queue
D.Bounties:Scan()
equal(#D.Net.queue, queueSize, "repeated scans coalesce reports")
-- Bring both clocks to the observation time before simulating delivery.
e:advance(d.epoch - e.epoch)
E.Net:Receive(report, "GUILD", "Numi-Tumi")
local sighting = E.Bounties:GetSighting("grave light")
check(sighting, "guild sighting received")
equal(sighting.witness, "Numi-Tumi", "witness comes from channel sender")
equal(sighting.map, 37)
equal(sighting.x, 3)
check(not next(E.Bounties.nearby), "remote report is not a local detection")
check(not E.Bounties.badge or not E.Bounties.badge:IsShown(), "remote report has no minimap badge")
E.Window:Show("bounties")
equal(E.Window.frame.height, 374, "reports preserve bounty window height")
check(E.Window.rows[1].data.right:find("Elwynn Forest", 1, true), "report row shows observer area")
check(E.Window.rows[1].data.detail:find("Witness: Numi-Tumi", 1, true), "hover identifies witness")
equal(E.PvP:Local().bountyKills, 0, "sighting cannot award points")
local expiry = sighting.expires
e:advance(30)
E.Net:Receive(report, "GUILD", "Numi-Tumi")
equal(E.Bounties:GetSighting("grave light").expires, expiry, "duplicate cannot refresh report lifetime")
E.Net:Receive(report, "GUILD", "Outsider Person")
check(not E.peers["outsider person"], "outside witness rejected")
E.Net:Receive(report, "WHISPER", "Numi-Tumi")
equal(E.Bounties:GetSighting("grave light").expires, expiry, "non-guild reports ignored")
local revisionText, observedText = report:match("^T|(%d+)|(%d+)|")
local function reportAt(timestamp, name, coords)
    return string.format("T|%.0f|%.0f|%s|%s", tonumber(revisionText) + 100, timestamp, coords or "37|3|4", name or "Grave Light")
end
E.Net:Receive(reportAt(E:ServerNow() + 60), "GUILD", "Numi-Tumi")
equal(E.Bounties:GetSighting("grave light").expires, expiry, "future reports rejected")
E.Net:Receive(reportAt(E:ServerNow(), "Unknown Victim"), "GUILD", "Numi-Tumi")
check(not E.Bounties.sightings["unknown victim"], "unlisted names cannot create reports")
E.Net:Receive(reportAt(E:ServerNow(), nil, "37|55|4"), "GUILD", "Numi-Tumi")
equal(E.Bounties:GetSighting("grave light").expires, expiry, "invalid map tile rejected")
-- A newer witness wins; an older report from a third client cannot replace it.
local newer = reportAt(E:ServerNow(), nil, "47|5|6")
E.Net:Receive(newer, "GUILD", "Other-Sailor")
equal(E.Bounties:GetSighting("grave light").witness, "Other-Sailor", "newest witness replaces earlier report")
E.Net:Receive(reportAt(tonumber(observedText) + 1), "GUILD", "Numi-Tumi")
equal(E.Bounties:GetSighting("grave light").map, 47, "out-of-order older report cannot replace latest area")
E.roster["other sailor"] = nil
check(not E.Bounties:GetSighting("grave light"), "departed witness is removed immediately")
-- Restore the original observation for the absolute expiry boundary.
E.peers["numi tumi"].sightingRevisions = {}
E.Net:Receive(report, "GUILD", "Numi-Tumi")
e:advance(60)
check(not E.Bounties:GetSighting("grave light"), "report expires at 90 seconds")
E.Net:Receive(report, "GUILD", "Numi-Tumi")
check(not E.Bounties:GetSighting("grave light"), "expired observation cannot be replayed")
E.Window:Refresh()
equal(E.Window.rows[1].data.right, "10 pts", "expired report restores reward text")
-- Delayed transport cannot renew old intelligence after leaving combat.
D.Net:Clear()
d.sent = {}
d:advance(30)
d.combat = true
D.Bounties:Scan()
check(#D.Net.queue > 0, "combat observation queued")
d:advance(91)
d.units.target = nil
D.Bounties:Scan()
check(not D.Bounties:GetSighting("grave light"), "local historical observation expires")
d.combat = false
d:drain()
equal(#d.sent, 0, "expired queued sighting is dropped before transmission")
d.instance = true
d.units.target = { first = "Grave", surname = "Light", faction = "Horde" }
D.Bounties:Scan()
equal(#D.Net.queue, 0, "instance sightings are not shared")
d.instance = false
D.Bounties:Scan()
check(D.Bounties:GetSighting("grave light"), "fresh observation replaces expired report")
check(D.Bounties:Remove("Grave Light"))
check(not D.Bounties:GetSighting("grave light"), "removed bounty hides its sighting")
d.env.SlashCmdList.MYCRADAR("off")
check(not next(D.Bounties.sightings), "disable clears ephemeral reports")
check(not next(D.Legacy.own), "disable clears shared Legacy goals")

-- Personal kill credit must not require honor, guess from corpses, or double-count
-- the separate honor message delivered for the same death.
local k = client("Numi", "Tumi")
local K = k.R
local victimGUID = "Player-1-00000002"
k.units.target = {
    first = "Grave", surname = "Light", faction = "Horde", class = "PALADIN",
    race = "Scourge", raceID = 5, guid = victimGUID,
}
check(K.Bounties:Add("Grave Light"))
k:event("PLAYER_TARGET_CHANGED")
k.units.target.dead = true
K.Bounties:Scan()
k:event("PARTY_KILL", k.guid, victimGUID)
equal(K.PvP:Local().undeadPaladins, 1, "personal no-honor undead paladin kill counts")
equal(K.PvP:Local().bountyKills, 1, "personal no-honor bounty kill awards points")
equal(K.PvP:Local().lifetime, 123, "no-honor kill does not alter WoW lifetime HKs")
k:event("PARTY_KILL", k.guid, victimGUID)
equal(K.PvP:Local().undeadPaladins, 1, "duplicate native kill event ignored")
k:honor("Grave Light", 90001)
equal(K.PvP:Local().undeadPaladins, 1, "honor after personal credit does not count twice")
k:honor("Grave Light", 90001)
equal(K.PvP:Local().undeadPaladins, 1, "duplicate honor after personal credit ignored")

-- A witnessed resurrection starts another life even within the merge window.
k:advance(2)
k.units.target.dead = false
k:event("PLAYER_TARGET_CHANGED")
k.units.target.dead = true
K.Bounties:Scan()
k:honor("Grave Light", 90002)
k:event("PARTY_KILL", k.guid, victimGUID)
equal(K.PvP:Local().undeadPaladins, 2, "personal after honor is also deduplicated")
equal(K.PvP:Local().bountyKills, 1, "no-honor path keeps the daily victim cap")

k:advance(2)
k.units.target.dead = false
k:event("PLAYER_TARGET_CHANGED")
k.petGUID = "Pet-0-1-2-3-4-00000001"
k.units.target.dead = true
K.Bounties:Scan()
k:event("PARTY_KILL", k.petGUID, victimGUID)
equal(K.PvP:Local().undeadPaladins, 3, "your pet's confirmed kill counts without honor")

-- Nearby deaths, other people's blows and hidden GUIDs are not personal credit.
k:advance(11)
k:event("UNIT_DIED", victimGUID)
K.Bounties:Scan()
equal(K.PvP:Local().undeadPaladins, 3, "a corpse or bare death event cannot score")
k:event("PARTY_KILL", "Player-1-00000003", victimGUID)
equal(K.PvP:Local().undeadPaladins, 3, "teammate's blow alone cannot score for you")
k:event("PARTY_KILL", SECRET, victimGUID)
k:event("PARTY_KILL", k.guid, SECRET)
k:event("PARTY_KILL", k.guid, "Creature-0-1-2-3-4-00000002")
k:event("PARTY_KILL", k.guid, "Player-1-00000099")
equal(K.PvP:Local().undeadPaladins, 3, "secret, NPC and unseen victim IDs cannot score")

-- Secret reads do not overwrite an identity observed before combat.
k.units.target.dead = false
k:event("PLAYER_TARGET_CHANGED")
k.units.target.class, k.units.target.guid = SECRET, SECRET
k.combat = true
k:event("PLAYER_TARGET_CHANGED")
k:event("PARTY_KILL", k.guid, victimGUID)
equal(K.PvP:Local().undeadPaladins, 4, "readable kill credit uses recent cached identity")
k:advance(181)
k:event("PARTY_KILL", k.guid, victimGUID)
equal(K.PvP:Local().undeadPaladins, 4, "expired classification cannot score a personal kill")
k.combat = false

-- A first-seen dead target may resolve a real kill event, but cannot score itself.
local m = client("Numi", "Tumi")
m.units.target = {
    first = "Bone", surname = "Hammer", faction = "Horde", class = "PALADIN",
    race = "Undead", raceID = 5, guid = "Player-1-00000005", dead = true,
}
m:event("PARTY_KILL", m.guid, "Player-1-00000005")
equal(m.R.PvP:Local().undeadPaladins, 1, "kill event can resolve a still-visible victim before next scan")
m.env.COMBATLOG_HONORGAIN, m.env.COMBATLOG_HONORGAIN_NO_RANK = nil, nil
m:advance(2)
m.units.target.dead = false
m:event("PLAYER_TARGET_CHANGED")
m.units.target.dead = true
m.petGUID = SECRET
m:event("PARTY_KILL", m.guid, "Player-1-00000005")
equal(m.R.PvP:Local().undeadPaladins, 2, "personal kill needs neither honor templates nor readable pet identity")
local receiver = client("Rhea", "Tide")
m:drain()
for _, packet in ipairs(m.sent) do receiver.R.Net:Receive(packet.message, packet.channel, "Numi-Tumi") end
equal(receiver.R:GuildDB().pvp["numi tumi"].undeadPaladins, 2, "no-honor kills reach the guild leaderboard")
equal(receiver.R:GuildDB().pvp["numi tumi"].lifetime, 123, "shared no-honor total does not change lifetime HKs")
m.R.Window:Show("pvp")
m.R.Window.metric = "undeadPaladins"
m.R.Window:Refresh()
equal(m.R.Window.rightHeading:GetText(), "KILLS", "custom counter is not mislabeled honorable kills")

k.env.SlashCmdList.MYCRADAR("off")
k:event("PARTY_KILL", k.guid, victimGUID)
check(not next(K.PvP.guids), "disable clears cached victim GUIDs")
equal(K.PvP:Local(), nil, "disabled addon cannot record personal kills")

-- Unsupported event registration is caught and named honor credit still works.
local registerEvent = methods.RegisterEvent
methods.RegisterEvent = function(self, event)
    if event == "PARTY_KILL" then error("unsupported event") end
    registerEvent(self, event)
end
local unsupported = client("Numi", "Tumi")
methods.RegisterEvent = registerEvent
check(unsupported.R.failedEvents.PARTY_KILL, "unsupported personal event does not prevent startup")
unsupported.units.target = {
    first = "Grave", surname = "Light", faction = "Horde", class = "PALADIN", race = "Scourge", raceID = 5,
}
unsupported:event("PLAYER_TARGET_CHANGED")
unsupported:honor("Grave Light", 90003)
equal(unsupported.R.PvP:Local().undeadPaladins, 1, "honor fallback survives unsupported personal kill event")

-- Same-name records cannot lend a previous GUID's race/class to another unit.
local changed = client("Numi", "Tumi")
changed.units.target = {
    first = "Grave", surname = "Light", faction = "Horde", class = "PALADIN", race = "Scourge", raceID = 5,
    guid = "Player-1-00000006",
}
changed:event("PLAYER_TARGET_CHANGED")
changed.units.target.guid, changed.units.target.class = "Player-1-00000007", SECRET
changed:event("PLAYER_TARGET_CHANGED")
changed:event("PARTY_KILL", changed.guid, "Player-1-00000006")
changed:event("PARTY_KILL", changed.guid, "Player-1-00000007")
equal(changed.R.PvP:Local().undeadPaladins, 0, "changed GUID does not inherit prior race/class")
changed.units.target.class = "PALADIN"
changed:event("PLAYER_TARGET_CHANGED")
changed:honor("Grave Light", 90004)
equal(changed.R.PvP:Local().undeadPaladins, 1, "later readable classification completes the same kill's credit")
changed:advance(181)
changed.R.PvP:Prune()
check(not next(changed.R.PvP.guids), "expired observed GUIDs are pruned")

-- No-honor bounty rewards also become available again on the next UTC day.
local daily = client("Numi", "Tumi")
daily.units.target = {
    first = "Grave", surname = "Light", faction = "Horde", class = "PALADIN", race = "Scourge", raceID = 5,
    guid = victimGUID,
}
daily.R.Bounties:Add("Grave Light")
daily:event("PARTY_KILL", daily.guid, victimGUID)
daily:advance(86400)
daily:event("PARTY_KILL", daily.guid, victimGUID)
equal(daily.R.PvP:Local().bountyKills, 2, "next UTC day can reward a no-honor kill")

-- Bounties copy the client's exact Unicode name; no keyboard transcription.
local u, v = client("Numi", "Tumi"), client("Rhea", "Tide")
local U = u.R
U.Window:Show("bounties")
check(not U.Window.addTarget:IsEnabled(), "add-target disabled without a player target")
u.units.target = { first = "Mørk", surname = "Épine", faction = "Horde", hostile = false }
u:event("PLAYER_TARGET_CHANGED")
check(U.Window.addTarget:IsEnabled(), "unflagged Horde target can be listed")
U.Window.addTarget.scripts.OnClick()
equal(U.Bounties:Own()[U:NameKey("Mørk Épine")], "Mørk Épine", "target button preserves every Unicode byte")
check(not U.Window.addTarget:IsEnabled(), "listed target cannot be added twice")
equal(U.Window.frame.height, 374, "quick-add does not expand the slim bounty window")
u.units.mouseover = { first = "Кровь", surname = "Тьмы", faction = "Horde" }
u.env.SlashCmdList.MYCRADAR("bounty mouseover")
equal(U.Bounties:Own()[U:NameKey("Кровь Тьмы")], "Кровь Тьмы", "mouseover command preserves Cyrillic names")
u.units.target = { first = "Đárk", surname = "Søul", faction = "Horde", dead = true }
u.env.SlashCmdList.MYCRADAR("bounty target")
equal(U.Bounties:Own()[U:NameKey("Đárk Søul")], "Đárk Søul", "target command also works on a corpse")
local playerLink = "|cffc69b6d|Hplayer:Żółć-Nøcturne:123:WHISPER|h[Żółć]|h|r"
U.Window.input:SetText(playerLink)
check(U.Window.add:IsEnabled(), "pasted player link enables manual add")
U.Window.add.scripts.OnClick()
equal(U.Bounties:Own()[U:NameKey("Żółć Nøcturne")], "Żółć-Nøcturne", "player-link payload retains full surname despite short label")
check(not U.Bounties:Add("Żółć Nøcturne"), "copied and linked names resolve to the same bounty")
check(not U.Bounties:Add("|Hitem:123|h[Mørk Épine]|h"), "non-player links are rejected")
check(not U.Bounties:Add("|Hplayer:Bad|h[Name]|h|Hspell:1|h[X]|h"), "extra hyperlink payload is rejected")
check(not U.Bounties:Add(SECRET), "secret name inputs cannot be inspected")
check(not U.Bounties:Add(string.rep("a", 513)), "oversized input rejected before parsing")
local beforeUnits = #U.Bounties:List()
for _, target in ipairs({
    { first = SECRET, surname = "Hidden", faction = "Horde" },
    { first = "Hidden", surname = "Faction", faction = SECRET },
    { first = "Friendly", surname = "Player", faction = "Alliance" },
    { first = "Enemy", surname = "Creature", faction = "Horde", player = false },
}) do
    u.units.target = target
    check(not U.Bounties:AddUnit("target"), "hidden, friendly or NPC target cannot be auto-listed")
end
equal(#U.Bounties:List(), beforeUnits, "rejected targets do not alter listings")
u:drain()
for _, packet in ipairs(u.sent) do
    check(#packet.message <= 255, "Unicode bounty packets obey byte limit")
    v.R.Net:Receive(packet.message, packet.channel, "Numi-Tumi")
end
local shared = v.R:GuildDB().bounties["numi tumi"].targets
equal(shared[v.R:NameKey("Mørk Épine")], "Mørk Épine", "accented target survives guild synchronization unchanged")
equal(shared[v.R:NameKey("Кровь Тьмы")], "Кровь Тьмы", "Cyrillic target survives guild synchronization unchanged")
equal(shared[v.R:NameKey("Żółć Nøcturne")], "Żółć-Nøcturne", "linked surname survives guild synchronization unchanged")
v.units.target = { first = "Żółć", surname = "Nøcturne", faction = "Horde" }
v:event("PLAYER_TARGET_CHANGED")
check(v.R.Bounties.nearby[v.R:NameKey("Żółć Nøcturne")], "linked Unicode bounty matches the visible player")
check(U.Bounties:Remove(playerLink), "player links also remove the author's listing")
check(U.Bounties:Add("Fifth Enemy"))
check(U.Bounties:Add("Sixth Enemy"))
u.units.target = { first = "Séventh", surname = "Enemy", faction = "Horde" }
u:event("PLAYER_TARGET_CHANGED")
check(not U.Window.addTarget:IsEnabled(), "five-name cap disables quick-add")
check(not U.Bounties:AddUnit("target"), "quick-add cannot bypass the five-name cap")
U.Window:Show("pvp")
check(not U.Window.addTarget:IsShown(), "quick-add stays confined to the bounty tab")

-- Different quest and Legacy goals turn into one run across zones and clients.
local planner, quester, spelunker = client("Numi", "Tumi"), client("Rhea", "Tide"), client("Other", "Sailor")
local Plan = planner.R
quester.timers, spelunker.timers = {}, {}
planner.quests = { { questID = 95787, title = "Take Two With Water" } }
quester.quests = { { questID = 95788, title = "Magics of the Drowned City" } }
for _, player in ipairs({ planner, spelunker }) do
    player.legacy[62032] = { name = "Experienced Spelunker", points = 1, criteria = {
        { name = "Gnomeregan", quantity = 0, required = 1, done = false, asset = 7800 },
        { name = "Ciudad sumergida", quantity = 0, required = 1, done = false, asset = 260243 },
    } }
end
spelunker.tracked = { 62032 }
quester.env.C_Map.GetBestMapForUnit = function() return 42 end
local function sharePlan(source)
    source.sent = {}
    source.R.Net:Clear()
    source.R.Quests:Broadcast(true)
    source.R.Legacy:Broadcast(true)
    source:drain()
    for _, packet in ipairs(source.sent) do
        Plan.Net:Receive(packet.message, packet.channel, source.first .. "-" .. source.surname)
    end
end
sharePlan(quester)
sharePlan(spelunker)
Plan.Window:Show("quests")
equal(#Plan.Window:Data(), 1, "one row combines all the dungeon goals")
local first = Plan.Window.rows[1]
equal(first.left:GetText(), "The Drowned City")
equal(first.right:GetText(), "You + 2 guildmates")
equal(Plan.Window.frame.height, 340, "dungeon row uses existing list space")
first.scripts.OnEnter()
local tooltip = table.concat(planner.env.GameTooltip.lines, "\n")
check(tooltip:find("You — Take Two With Water", 1, true), "hover lists your own reason")
check(tooltip:find("Rhea-Tide — Magics of the Drowned City", 1, true), "hover shows a different quest in another zone")
check(tooltip:find("Other-Sailor — Legacy · Defeat Min'loth the Serpent", 1, true),
    "hover identifies the Legacy boss using its asset even in a different locale")
Plan.Window.questViews.legacy.scripts.OnClick()
check(not first.data or not first.data.dungeon, "one-run row belongs to Shared Quests only")
Plan.Window.questViews.quests.scripts.OnClick()
quester:advance(21)
quester.quests = { { questID = 95787, title = "Take Two With Water" } }
sharePlan(quester)
Plan.peers["other sailor"].legacySeen = Plan:Clock() - 420
Plan.Window:Refresh()
check(not first:IsShown(), "same quest alone or expired Legacy do not qualify")
spelunker:advance(21)
spelunker.legacy[62032].criteria[2].done = true
sharePlan(spelunker)
check(not Plan.Dungeons:Best(), "completed peer goal expires on its next snapshot")
planner.env.C_QuestLog.IsComplete = function() return SECRET end
Plan.Quests:Broadcast(false)
check(not Plan.Quests.own[95787], "unreadable quest completion cannot suggest a run")
print("PASS: " .. assertions .. " assertions")
