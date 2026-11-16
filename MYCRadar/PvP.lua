local _, R = ...
R.PvP = { enemies = {}, seen = {}, lastBroadcast = -9999 }
local P = R.PvP
local MAX_COUNT = 100000000

function P:ClearSession()
    self.enemies, self.seen = {}, {}
    self.lastBroadcast = -9999
end

function P:Local()
    local db = R:CharGuildDB()
    if not db then return nil end
    if type(db.pvp) ~= "table" then
        db.pvp = { undeadPaladins = 0, bountyKills = 0, claimed = {}, since = R:Now() }
    end
    db.pvp.claimed = type(db.pvp.claimed) == "table" and db.pvp.claimed or {}
    return db.pvp
end

function P:Observe(unit, name, faction)
    local key = R:NameKey(name)
    if not key then return end
    local _, class = R:Read(UnitClass, unit)
    local _, race, raceID = R:Read(UnitRace, unit)
    local readable = not R:IsSecret(class) and not R:IsSecret(race) and not R:IsSecret(raceID)
        and type(class) == "string" and (type(race) == "string" or type(raceID) == "number")
    local previous = self.enemies[key]
    local classified = readable and class == "PALADIN" and
        (race == "Scourge" or race == "Undead" or raceID == 5) or false
    local classifiedAt = readable and R:Clock() or nil
    if not readable and previous and previous.classifiedAt and R:Clock() - previous.classifiedAt <= 180 then
        classified, classifiedAt = previous.undeadPaladin, previous.classifiedAt
    end
    self.enemies[key] = {
        time = R:Clock(), horde = faction == "Horde",
        undeadPaladin = classified, classifiedAt = classifiedAt,
    }
end

-- Compile Blizzard's localized printf template, including reordered %1$s fields.
-- The first argument is the victim; generic bonus-honor messages never match.
function P:CompileFormat(template)
    if R:IsSecret(template) or type(template) ~= "string" or template == "" then return nil end
    local pattern, at, argument, captures, victimCapture = { "^" }, 1, 0, 0, nil
    while at <= #template do
        local char = template:sub(at, at)
        if char == "%" then
            local rest = template:sub(at)
            if rest:sub(1, 2) == "%%" then
                pattern[#pattern + 1], at = "%%", at + 2
            else
                local token, position, kind = rest:match("^(%%(%d+)%$([sd]))")
                if not token then token, kind = rest:match("^(%%([sd]))") end
                if not token then return nil end
                argument = argument + 1
                local number = tonumber(position) or argument
                captures = captures + 1
                if number == 1 and kind == "s" then victimCapture = captures end
                pattern[#pattern + 1] = kind == "d" and "(%d+)" or "(.+)"
                at = at + #token
            end
        else
            pattern[#pattern + 1] = char:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            at = at + 1
        end
    end
    if not victimCapture then return nil end
    pattern[#pattern + 1] = "$"
    return { pattern = table.concat(pattern), victim = victimCapture }
end

function P:HonorFormats()
    local result = {}
    for _, key in ipairs({
        "COMBATLOG_HONORGAIN", "COMBATLOG_HONORGAIN_NO_RANK",
        "COMBATLOG_HONORGAIN_EXHAUSTION1", "COMBATLOG_HONORGAIN_EXHAUSTION2",
    }) do
        local compiled = self:CompileFormat(_G[key])
        if compiled then result[#result + 1] = compiled end
    end
    return result
end

function P:HonorVictim(message)
    if R:IsSecret(message) or type(message) ~= "string" or #message > 1024 then return nil end
    for _, format in ipairs(self:HonorFormats()) do
        local captures = { message:match(format.pattern) }
        local name = R:ValidName(captures[format.victim])
        if name then return name end
    end
end

function P:OnHonor(message, lineID)
    if not R:InGuild() then return end
    local name = self:HonorVictim(message)
    local key = R:NameKey(name)
    if not key then return end
    local now = R:Clock()
    for id, at in pairs(self.seen) do if now - at > 180 then self.seen[id] = nil end end
    local id = R:SafeNumber(lineID, 1, 9007199254740991)
    id = id and ("line:" .. id) or (key .. ":" .. math.floor(now / 10))
    if self.seen[id] then return end
    self.seen[id] = now
    local enemy = self.enemies[key]
    if not enemy or now - enemy.time > 180 then return end
    local db = self:Local()
    if not db then return end
    local changed = false
    if enemy.undeadPaladin and enemy.classifiedAt and now - enemy.classifiedAt <= 180 then
        db.undeadPaladins = (db.undeadPaladins or 0) + 1
        changed = true
    end
    -- One reward per full victim name per UTC day, regardless of sponsors.
    local day = date("!%Y-%m-%d", R:Now())
    for victim, claimedDay in pairs(db.claimed) do
        if claimedDay ~= day then db.claimed[victim] = nil end
    end
    if enemy.horde and R.Bounties:IsListed(key) and db.claimed[key] ~= day then
        db.claimed[key] = day
        db.bountyKills = (db.bountyKills or 0) + 1
        R:Chat("+10 bounty points: " .. R:CleanName(name) .. ".")
        changed = true
    end
    if changed then self:Broadcast(true) end
end

function P:Sample()
    local localDB = self:Local()
    if not localDB then return nil end
    local lifetime = R:Read(GetPVPLifetimeStats)
    lifetime = R:SafeNumber(lifetime, 0, MAX_COUNT)
    if lifetime then localDB.lifetime = math.floor(lifetime) end
    local _, class = R:Read(UnitClass, "player")
    if R:IsSecret(class) or type(class) ~= "string" or not class:match("^[A-Z]+$") then class = "UNKNOWN" end
    return localDB, class
end

function P:Broadcast(force)
    if not R:InGuild() then return end
    if not force and R:Clock() - self.lastBroadcast < 300 then return end
    local db, class = self:Sample()
    local name = R:UnitName("player")
    if not db or not name then return end
    local revision = R:NextRevision()
    local lifetime = db.lifetime and string.format("%.0f", db.lifetime) or "-"
    local message = string.format("V|%.0f|%s|%.0f|%.0f|%s",
        revision, lifetime, db.undeadPaladins or 0, db.bountyKills or 0, class)
    self:Receive(name, message)
    R.Net:Queue(message, "V", true)
    self.lastBroadcast = R:Clock()
end

function P:Receive(sender, message)
    local revision, lifetime, undead, bounties, class =
        message:match("^V|(%d+)|([%d%-]+)|(%d+)|(%d+)|([A-Z]+)$")
    if not revision then return end
    revision, undead, bounties = tonumber(revision), tonumber(undead), tonumber(bounties)
    local hk = lifetime ~= "-" and tonumber(lifetime) or nil
    if not R:SafeNumber(revision, 1, 9007199254740991) or
        not R:SafeNumber(undead, 0, MAX_COUNT) or not R:SafeNumber(bounties, 0, MAX_COUNT) or
        (lifetime ~= "-" and not R:SafeNumber(hk, 0, MAX_COUNT)) or #class > 16 then return end
    local db, key = R:GuildDB(), R:NameKey(sender)
    if not db or not key then return end
    local old = db.pvp[key]
    if old and revision <= (old.revision or 0) then return end
    db.pvp[key] = {
        name = R:CleanName(sender), lifetime = hk, undeadPaladins = undead,
        bountyKills = bounties, class = class, revision = revision, updated = R:Now(),
    }
end

function P:Leaderboard(metric)
    local rows, db = {}, R:GuildDB()
    if not db then return rows end
    for key, row in pairs(db.pvp) do
        if R:IsMember(key) then
            local value = metric == "points" and (row.bountyKills or 0) * 10 or row[metric]
            if value ~= nil then
                rows[#rows + 1] = { key = key, name = row.name, value = value, updated = row.updated }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.value == b.value then return a.key < b.key end
        return a.value > b.value
    end)
    return rows
end

function P:Prune()
    for key, row in pairs(self.enemies) do
        if R:Clock() - row.time > 180 then self.enemies[key] = nil end
    end
end
