local _, R = ...
R.Bounties = { units = {}, nearby = {}, lastBroadcast = -9999 }
local B = R.Bounties
local MAX_OWN = 5

function B:ClearNearby()
    self.nearby = {}
    self.lastBroadcast = -9999
    if self.badge then self.badge:Hide() end
end

function B:Own()
    local db = R:CharGuildDB()
    if not db then return nil end
    db.bounties = type(db.bounties) == "table" and db.bounties or {}
    return db.bounties
end

function B:Add(name)
    name = R:ValidName(name)
    if not name then return false, "Enter a full Horde character name, including surname." end
    local db = self:Own()
    if not db then return false, "Join your guild first." end
    local key, count = R:NameKey(name), 0
    if db[key] then return false, "That name is already on your list." end
    for _ in pairs(db) do count = count + 1 end
    if count >= MAX_OWN then return false, "You can list five names. Remove one to add another." end
    db[key] = name
    self:Broadcast(true)
    return true, "Bounty listed: " .. name .. "."
end

function B:Remove(name)
    local db, key = self:Own(), R:NameKey(name)
    if not db or not key or not db[key] then return false, "You can remove names you added." end
    db[key] = nil
    self:Broadcast(true)
    self:Scan()
    return true, "Removed your listing for " .. R:CleanName(name) .. "."
end

function B:Receive(sender, revision, records)
    if #records > MAX_OWN then return false end
    local db, author = R:GuildDB(), R:NameKey(sender)
    if not db or not author then return false end
    local names = {}
    for _, name in ipairs(records) do
        local clean = R:ValidName(name)
        local key = R:NameKey(clean)
        if not key or names[key] then return false end
        names[key] = clean
    end
    local old = db.bounties[author]
    if old and revision <= (old.revision or 0) then return false end
    -- A complete owner snapshot also removes deleted names; no replay can revive them.
    db.bounties[author] = { name = R:CleanName(sender), revision = revision, targets = names, updated = R:Now() }
    return true
end

function B:Broadcast(force)
    if not R:InGuild() or (not force and R:Clock() - self.lastBroadcast < 300) then return end
    local own, name = self:Own(), R:UnitName("player")
    if not own or not name then return end
    local names = {}
    for _, target in pairs(own) do names[#names + 1] = target end
    table.sort(names)
    -- Apply locally immediately; the network snapshot receives its own later revision.
    self:Receive(name, R:NextRevision(), names)
    R.Net:QueueSnapshot("B", names, "", true)
    self.lastBroadcast = R:Clock()
end

function B:List()
    local db, targets = R:GuildDB(), {}
    if not db then return {} end
    local localPvP = R.PvP:Local()
    local claimed = localPvP and localPvP.claimed or {}
    local day = date("!%Y-%m-%d", R:Now())
    local mine = R:NameKey(R:UnitName("player"))
    for author, row in pairs(db.bounties) do
        if R:IsMember(author) then
            for key, name in pairs(row.targets or {}) do
                local target = targets[key] or { key = key, name = name, authors = {}, own = false }
                targets[key] = target
                target.authors[#target.authors + 1] = row.name
                if author == mine then target.own = true end
            end
        end
    end
    local result = {}
    for key, target in pairs(targets) do
        target.nearby = self.nearby[key] ~= nil
        target.claimed = claimed[key] == day
        table.sort(target.authors)
        result[#result + 1] = target
    end
    table.sort(result, function(a, b)
        if a.nearby ~= b.nearby then return a.nearby end
        return a.key < b.key
    end)
    return result
end

function B:IsListed(key)
    local db = R:GuildDB()
    if not db then return false end
    for author, row in pairs(db.bounties) do
        if R:IsMember(author) and row.targets and row.targets[key] then return true end
    end
    return false
end

local function plainTrue(value)
    return not R:IsSecret(value) and value == true
end

function B:Inspect(unit, nearby)
    if not plainTrue(R:Read(UnitExists, unit)) or not plainTrue(R:Read(UnitIsVisible, unit)) or
        not plainTrue(R:Read(UnitIsPlayer, unit)) or
        not plainTrue(R:Read(UnitCanAttack, "player", unit)) then return end
    local name = R:UnitName(unit)
    local faction = R:Read(UnitFactionGroup, unit)
    if not name or R:IsSecret(faction) or type(faction) ~= "string" then return end
    R.PvP:Observe(unit, name, faction)
    local key = R:NameKey(name)
    local dead = R:Read(UnitIsDeadOrGhost, unit)
    if faction == "Horde" and not R:IsSecret(dead) and dead == false and self:IsListed(key) then
        nearby[key] = name
    end
end

function B:Scan()
    if not R:InGuild() then self:ClearNearby(); return end
    local nearby = {}
    self:Inspect("target", nearby)
    self:Inspect("mouseover", nearby)
    for unit in pairs(self.units) do self:Inspect(unit, nearby) end
    local fresh
    for key, name in pairs(nearby) do
        if not self.nearby[key] then fresh = name; break end
    end
    self.nearby = nearby
    self:UpdateBadge()
    if fresh then R:Toast("Bounty spotted", fresh .. " is visible nearby.", "B:" .. R:NameKey(fresh), "bounty") end
end

function B:UpdateBadge()
    local count = 0
    for _ in pairs(self.nearby) do count = count + 1 end
    if count == 0 then if self.badge then self.badge:Hide() end; return end
    if not Minimap then return end
    if not self.badge then
        local f = CreateFrame("Button", "MYCRadarBountyBadge", Minimap, "BackdropTemplate")
        f:SetSize(22, 22)
        f:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
        f:SetFrameStrata("HIGH")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.11, 0.04, 0.03, 0.96)
        f:SetBackdropBorderColor(0.95, 0.45, 0.22, 1)
        f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.label:SetPoint("CENTER")
        f:SetScript("OnClick", function() R.Window:Show("bounties") end)
        f:SetScript("OnEnter", function()
            GameTooltip:SetOwner(f, "ANCHOR_LEFT")
            GameTooltip:AddLine("MYC bounties nearby", 1, 0.5, 0.25)
            local names = {}
            for _, name in pairs(B.nearby) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do GameTooltip:AddLine(name, 1, 1, 1) end
            GameTooltip:AddLine("Seen on target, mouseover or nameplates.", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Click to open the bounty board.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.badge = f
    end
    self.badge.label:SetText(count)
    self.badge:Show()
end
