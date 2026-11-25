local addonName, R = ...
R.name = addonName
R.version = "2.4.0"
R.prefix = "MYCRadar2"
R.peers = {}
R.roster = {}
R.lastToast = {}
R.alertKeys = {}

function R:IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function R:Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

function R:Now()
    return (time and time()) or 0
end

function R:Clock()
    return (GetTime and GetTime()) or 0
end

function R:ServerNow()
    return self:SafeNumber(self:Read(GetServerTime), 1, 9999999999) or self:Now()
end

function R:SafeNumber(n, minimum, maximum)
    if issecretvalue and issecretvalue(n) then return nil end
    if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then return nil end
    if n < minimum or n > maximum then return nil end
    return n
end

function R:CleanName(name)
    return self:ValidName(name) or "Guildmate"
end

function R:ValidName(name)
    if self:IsSecret(name) or type(name) ~= "string" or #name > 80 then return nil end
    name = name:match("^%s*(.-)%s*$"):gsub("%s+", " ")
    if #name < 2 or name:find("[%c%d|,%%:;\\/]") then return nil end
    return name
end

function R:NameKey(name)
    name = self:ValidName(name)
    return name and name:lower():gsub("%-", " "):gsub("%s+", " ") or nil
end

function R:UnitName(unit)
    local first, surname = self:Read(UnitFullName, unit)
    if self:IsSecret(first) or self:IsSecret(surname) then return nil end
    first = self:ValidName(first)
    if not first then return self:ValidName(self:Read(UnitName, unit)) end
    surname = self:ValidName(surname)
    return surname and self:ValidName(first .. " " .. surname) or first
end

function R:IsMember(key)
    return not self.rosterReady or self.roster[key] == true
end

function R:RefreshRoster()
    local count = self:Read(GetNumGuildMembers)
    if not self:SafeNumber(count, 1, 2000) then return end
    local members = {}
    for i = 1, count do
        local key = self:NameKey(self:Read(GetGuildRosterInfo, i))
        if key then members[key] = true end
    end
    local mine = self:NameKey(self:UnitName("player"))
    if not mine or not members[mine] then return end
    self.roster, self.rosterReady = members, true
end

function R:NextRevision()
    self.charDB.sequence = math.max(self.charDB.sequence or 0, self:Now() * 1000) + 1
    return self.charDB.sequence
end

function R:Chat(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff37d6c0MYC Radar|r  " .. tostring(msg))
    end
end

function R:IsEnabled()
    return self.db and self.db.settings and self.db.settings.enabled ~= false
end

function R:InGuild()
    if not self:IsEnabled() then return false end
    if not IsInGuild or not IsInGuild() then return false end
    return self:UpdateGuild() ~= nil
end

local function mergeLatest(destination, source, field)
    for key, row in pairs(type(source) == "table" and source or {}) do
        local previous = destination[key]
        if type(row) == "table" and (type(previous) ~= "table" or
            (tonumber(row[field]) or 0) > (tonumber(previous[field]) or 0)) then
            destination[key] = row
        end
    end
end

local function mergePvP(old, recent, lastOldScore)
    if type(recent) ~= "table" then return old end
    old = type(old) == "table" and old or {}
    local oldSince, recentSince = tonumber(old.since), tonumber(recent.since)
    local separate = oldSince and recentSince and lastOldScore and
        oldSince < recentSince and lastOldScore < recentSince
    local claims, duplicates = {}, 0
    for victim, day in pairs(old.claimed or {}) do claims[victim] = day end
    for victim, day in pairs(recent.claimed or {}) do
        if claims[victim] == day then duplicates = duplicates + 1 end
        if not claims[victim] or claims[victim] < day then claims[victim] = day end
    end
    local function total(field, overlap)
        local before, after = tonumber(old[field]) or 0, tonumber(recent[field]) or 0
        if separate then return math.max(before, after, before + after - overlap) end
        return math.max(before, after)
    end
    return {
        since = oldSince and recentSince and math.min(oldSince, recentSince) or oldSince or recentSince,
        lifetime = recent.lifetime or old.lifetime,
        undeadPaladins = total("undeadPaladins", 0),
        bountyKills = total("bountyKills", duplicates),
        claimed = claims,
    }
end

function R:RecoverGuildKey(blank)
    local aliases = self.charDB.realmGuildKeys
    if aliases[blank] then return aliases[blank] end
    local guilds, characterGuilds = self.db.guilds, self.charDB.guilds
    local oldKey
    for key, entry in pairs(characterGuilds) do
        if type(key) == "string" and type(entry) == "table" and key ~= blank and
            key:sub(1, #blank) == blank then
            -- The character's own save must identify exactly one historical realm.
            if oldKey then return blank end
            oldKey = key
        end
    end
    if not oldKey then return blank end

    local oldGuild = type(guilds[oldKey]) == "table" and guilds[oldKey] or {}
    guilds[oldKey] = oldGuild
    oldGuild.pvp = type(oldGuild.pvp) == "table" and oldGuild.pvp or {}
    oldGuild.bounties = type(oldGuild.bounties) == "table" and oldGuild.bounties or {}
    local own = self:NameKey(self:UnitName("player"))
    local oldScore = own and oldGuild.pvp[own]
    local old, recent = characterGuilds[oldKey], characterGuilds[blank]
    if type(recent) == "table" then
        old.pvp = mergePvP(old.pvp, recent.pvp, oldScore and tonumber(oldScore.updated))
        old.professions = type(old.professions) == "table" and old.professions or {}
        mergeLatest(old.professions, recent.professions, "updated")

        -- Prefer current listings when the two buckets together exceed the board limit.
        local names, count, older = {}, 0, {}
        for key, name in pairs(recent.bounties or {}) do
            names[key], count = name, count + 1
        end
        for key in pairs(old.bounties or {}) do older[#older + 1] = key end
        table.sort(older)
        for _, key in ipairs(older) do
            if not names[key] then
                if count < 5 then
                    names[key], count = old.bounties[key], count + 1
                else
                    old.realmBountyOverflow = old.realmBountyOverflow or {}
                    old.realmBountyOverflow[key] = old.bounties[key]
                end
            end
        end
        old.bounties = names
    end
    local recentGuild = guilds[blank]
    if type(recentGuild) == "table" and not self.db.realmGuildKeys[blank] then
        mergeLatest(oldGuild.pvp, recentGuild.pvp, "revision")
        mergeLatest(oldGuild.bounties, recentGuild.bounties, "revision")
        self.db.realmGuildKeys[blank] = oldKey
    end
    aliases[blank] = oldKey
    return oldKey
end

function R:UpdateGuild()
    if not self.db or not self.charDB then return nil end
    local name = self:Read(GetGuildInfo, "player")
    if self:IsSecret(name) or type(name) ~= "string" or name == "" or
        self:Read(IsInGuild) ~= true then name = nil end
    local realm = self:Read(GetRealmName)
    if self:IsSecret(realm) or type(realm) ~= "string" then realm = "" end
    local key
    if name then
        local blank = name .. "@"
        key = realm ~= "" and (blank .. realm) or self:RecoverGuildKey(blank)
    end
    if key ~= self.guildKey then
        self.guildKey = key
        self.peers = {}
        self.roster, self.rosterReady = {}, false
        self.alertKeys = {}
        if self.Net then self.Net:Clear() end
        if self.Quests then self.Quests:Invalidate() end
        if self.Legacy then self.Legacy:Invalidate() end
        if self.PvP then self.PvP:ClearSession() end
        if self.Bounties then self.Bounties:ClearNearby() end
        if self.Professions then self.Professions.lastBroadcast = -9999 end
    end
    if not key then return nil end
    self.db.guilds[key] = self.db.guilds[key] or {}
    local guild = self.db.guilds[key]
    guild.pvp = type(guild.pvp) == "table" and guild.pvp or {}
    guild.bounties = type(guild.bounties) == "table" and guild.bounties or {}
    self.charDB.guilds[key] = self.charDB.guilds[key] or { professions = {} }
    if type(self.charDB.guilds[key].professions) ~= "table" then
        self.charDB.guilds[key].professions = {}
    end
    return key
end

function R:GuildDB()
    if not self:InGuild() then return nil end
    return self.db.guilds[self.guildKey]
end

function R:CharGuildDB()
    if not self:InGuild() then return nil end
    return self.charDB.guilds[self.guildKey]
end

function R:InitializeDB()
    MYCRadarDB = type(MYCRadarDB) == "table" and MYCRadarDB or {}
    MYCRadarCharDB = type(MYCRadarCharDB) == "table" and MYCRadarCharDB or {}
    local db, charDB = MYCRadarDB, MYCRadarCharDB
    db.version = 2
    db.guilds = type(db.guilds) == "table" and db.guilds or {}
    db.realmGuildKeys = type(db.realmGuildKeys) == "table" and db.realmGuildKeys or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.enabled == nil then db.settings.enabled = true end
    if db.settings.alerts == nil then db.settings.alerts = true end
    charDB.guilds = type(charDB.guilds) == "table" and charDB.guilds or {}
    charDB.realmGuildKeys = type(charDB.realmGuildKeys) == "table" and charDB.realmGuildKeys or {}
    self.db = db
    self.charDB = charDB
    for _, guild in pairs(db.guilds) do
        if type(guild) == "table" then guild.prices = nil end
    end
    self:UpdateGuild()
end

function R:Age(seconds)
    if seconds < 60 then return "now" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m" end
    return math.floor(seconds / 3600) .. "h"
end

function R:Toast(headline, detail, key, group)
    if not self:IsEnabled() or self.db.settings.alerts == false then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local now = self:Clock()
    group = group or "quest"
    if now - (self.lastToast[group] or -99999) < (group == "bounty" and 30 or 150) then return end
    if key and self.alertKeys[key] and now - self.alertKeys[key] < 1800 then return end
    if key then self.alertKeys[key] = now end
    self.lastToast[group] = now
    if not self.toastFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetSize(300, 44)
        f:SetPoint("TOP", UIParent, "TOP", 0, -125)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.025, 0.08, 0.12, 0.96)
        f:SetBackdropBorderColor(0.16, 0.80, 0.71, 0.90)
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
        label:SetPoint("RIGHT", f, "RIGHT", -10, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        sub:SetPoint("RIGHT", f, "RIGHT", -10, 0)
        sub:SetJustifyH("LEFT")
        sub:SetWordWrap(false)
        f.label, f.sub = label, sub
        self.toastFrame = f
    end
    self.toastFrame.label:SetText(headline)
    self.toastFrame.sub:SetText(detail)
    self.toastFrame:Show()
    self.toastSerial = (self.toastSerial or 0) + 1
    local serial = self.toastSerial
    if C_Timer and C_Timer.After then
        C_Timer.After(7, function()
            if self.toastSerial == serial and self.toastFrame then self.toastFrame:Hide() end
        end)
    end
end
