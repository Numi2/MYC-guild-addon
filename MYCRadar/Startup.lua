local addonName, R = ...
local f = CreateFrame("Frame")
R.failedEvents = {}

function R:Sync(request)
    if not self:InGuild() then return false end
    if request and self.lastRequest and self:Clock() - self.lastRequest < 60 then return false end
    if request then
        self.lastRequest = self:Clock()
        self.Net:Queue("H", "H", true)
    end
    self.Quests:Broadcast(true)
    self.Legacy:Broadcast(true)
    self.PvP:Broadcast(true)
    self.Bounties:Broadcast(true)
    self.Professions:Broadcast(true)
    return true
end

local function Start()
    if R.started then return end
    R.started = true
    R:UpdateGuild()
    R:RefreshRoster()
    R.Tooltip:Install()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        local ok, status = pcall(C_ChatInfo.RegisterAddonMessagePrefix, R.prefix)
        R.commReady = ok and status ~= false
    end
    if C_GuildInfo and C_GuildInfo.GuildRoster and R:InGuild() then pcall(C_GuildInfo.GuildRoster) end
    if C_Timer and C_Timer.After then C_Timer.After(5 + math.random(0, 5), function() R:Sync(true) end) end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(1.5, function() R.Net:SendNext() end)
        C_Timer.NewTicker(1, function() R.Bounties:Scan() end)
        C_Timer.NewTicker(3, function() R.Window:Refresh() end)
        C_Timer.NewTicker(60, function()
            R:UpdateGuild()
            R.Quests:Broadcast(false)
            R.Legacy:Broadcast(false)
            R.PvP:Broadcast(false)
            R.PvP:Prune()
            R.Bounties:Broadcast(false)
            R.Professions:Broadcast(false)
            R.Net:PrunePeers()
        end)
    end
end

local function ResetGuild()
    if not R.db then return end
    local before = R.guildKey
    R:UpdateGuild()
    R:RefreshRoster()
    if R.guildKey ~= before then
        R.lastRequest = nil
        if R.guildKey and C_Timer and C_Timer.After then
            C_Timer.After(4, function() R:Sync(true) end)
        end
    end
end

local function SampleSoon()
    if R.pvpPending or not R:IsEnabled() then return end
    if C_Timer and C_Timer.After then
        R.pvpPending = true
        C_Timer.After(1, function() R.pvpPending = false; R.PvP:Broadcast(true) end)
    end
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName then R:InitializeDB() end
        return
    elseif event == "PLAYER_LOGIN" then
        Start()
        return
    elseif event == "PLAYER_GUILD_UPDATE" or event == "GUILD_ROSTER_UPDATE" then
        ResetGuild()
        return
    end
    if not R:IsEnabled() then return end
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == R.prefix and R.commReady then R.Net:Receive(message, channel, sender) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        R:UpdateGuild()
        R.Quests:Soon()
        R.Legacy:Soon()
        R.PvP:Broadcast(false)
        R.Bounties:Broadcast(false)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "QUEST_LOG_UPDATE" or
        event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
        R.Quests:Soon()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" or event == "TRADE_SKILL_LIST_UPDATE" then
        R.Professions:Soon()
    elseif event == "CRITERIA_UPDATE" or event == "ACHIEVEMENT_EARNED" or
        event == "TRACKED_ACHIEVEMENT_UPDATE" or event == "TRACKED_ACHIEVEMENT_LIST_CHANGED" or
        event == "CONTENT_TRACKING_UPDATE" then
        R.Legacy:Soon()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if not R:IsSecret(unit) and type(unit) == "string" and unit:match("^nameplate%d+$") then
            R.Bounties.units[unit] = true
            R.Bounties:Scan()
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if not R:IsSecret(unit) and type(unit) == "string" then R.Bounties.units[unit] = nil end
        R.Bounties:Scan()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_REGEN_ENABLED" then
        R.Bounties:Scan()
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        local message = ...
        local lineID = select(11, ...)
        R.PvP:OnHonor(message, lineID)
        SampleSoon()
    elseif event == "PARTY_KILL" then
        R.PvP:OnPartyKill(...)
    elseif event == "PLAYER_PVP_KILLS_CHANGED" then
        SampleSoon()
    end
end)

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "PLAYER_REGEN_ENABLED", "CHAT_MSG_COMBAT_HONOR_GAIN", "PLAYER_PVP_KILLS_CHANGED", "PARTY_KILL",
    "CRITERIA_UPDATE", "ACHIEVEMENT_EARNED", "TRACKED_ACHIEVEMENT_UPDATE",
    "TRACKED_ACHIEVEMENT_LIST_CHANGED", "CONTENT_TRACKING_UPDATE",
}) do
    if not pcall(f.RegisterEvent, f, event) then R.failedEvents[event] = true end
end

local function status()
    local peers = 0
    for _, peer in pairs(R.peers) do
        if peer.lastSeen and R:Clock() - peer.lastSeen < 600 then peers = peers + 1 end
    end
    R:Chat("v" .. R.version .. " | " .. (R:IsEnabled() and "ON" or "OFF") ..
        " | Guild peers: " .. peers .. " | Bounties: " .. #R.Bounties:List() .. " | Outbox: " .. #R.Net.queue)
    R:Chat("Guild sync " .. (R.commReady and "ready" or "unavailable") ..
        ". Named honorable kill tracking " ..
        ((#R.PvP:HonorFormats() > 0 and not R.failedEvents.CHAT_MSG_COMBAT_HONOR_GAIN) and "available" or "unavailable") .. ".")
    local stats = R.PvP.killStats
    R:Chat("Personal kill event " .. (R.failedEvents.PARTY_KILL and "unavailable" or "registered") ..
        " | Received: " .. stats.events .. " | Hidden: " .. stats.hidden ..
        " | Unmapped: " .. stats.unmapped .. " | Added: " .. stats.recorded .. ".")
    for event in pairs(R.failedEvents) do R:Chat("Unsupported event: " .. event) end
end

SLASH_MYCRADAR1 = "/myc"
SLASH_MYCRADAR2 = "/mycradar"
SlashCmdList.MYCRADAR = function(input)
    input = (input or ""):match("^%s*(.-)%s*$")
    local command, argument = input:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    if command == "" then
        R.Window:Toggle()
    elseif command == "pvp" or command == "bounties" or command == "quests" or command == "crafters" then
        R.Window:Show(command)
    elseif command == "bounty" then
        local action, name = argument:match("^(%S+)%s+(.+)$")
        local _, message
        if action == "add" then
            _, message = R.Bounties:Add(name)
        elseif action == "remove" then
            _, message = R.Bounties:Remove(name)
        else
            message = "Use /myc bounty add Full Name or /myc bounty remove Full Name."
        end
        R:Chat(message)
        R.Window:Refresh()
    elseif command == "off" then
        R.db.settings.enabled = false
        R.Net:Clear()
        R.Bounties:ClearNearby()
        R.Legacy:Invalidate()
        R.PvP:ClearSession()
        if R.toastFrame then R.toastFrame:Hide() end
        R.Window:Refresh()
        R:Chat("Disabled. /myc on to resume.")
    elseif command == "on" then
        R.db.settings.enabled = true
        R.lastRequest = nil
        R:Sync(true)
        R:Chat("Enabled.")
    elseif command == "quiet" then
        R.db.settings.alerts = not R.db.settings.alerts
        if not R.db.settings.alerts and R.toastFrame then R.toastFrame:Hide() end
        R:Chat("Popup notifications " .. (R.db.settings.alerts and "on" or "off") .. ".")
    elseif command == "sync" then
        R:Chat(R:Sync(true) and "Guild refresh queued." or "Refresh is unavailable; wait a minute and check guild membership.")
    elseif command == "status" then
        status()
    else
        R:Chat("/myc opens the window. Tabs: pvp, bounties, quests, crafters.")
        R:Chat("/myc bounty add Full Name | bounty remove Full Name | quiet | off | on | sync | status")
    end
end
