local _, R = ...
R.Net = { queue = {}, lookup = {}, lastSend = -9999, lastReply = -9999, errors = 0 }
local N = R.Net
local MAX_PAGES = 64

function N:Clear()
    self.queue, self.lookup = {}, {}
    self.lastSend, self.lastReply = -9999, -9999
end

function N:Queue(message, key, priority)
    if not R:InGuild() or type(message) ~= "string" or #message > 255 then return false end
    key = key or message
    if self.lookup[key] then
        local row = self.lookup[key]
        row.text, row.at, row.tries = message, R:Clock(), 0
        return true
    end
    if #self.queue >= 90 then return false end
    local row = { text = message, key = key, at = R:Clock(), tries = 0 }
    if priority then table.insert(self.queue, 1, row) else self.queue[#self.queue + 1] = row end
    self.lookup[key] = row
    return true
end

function N:QueueSnapshot(kind, records, header, priority)
    local pages, current = {}, ""
    for _, record in ipairs(records) do
        if #record > 170 then return false end
        local nextPage = current == "" and record or current .. "," .. record
        if #nextPage > 170 then
            pages[#pages + 1], current = current, record
        else
            current = nextPage
        end
    end
    pages[#pages + 1] = current
    if #pages > MAX_PAGES then return false end
    for i = #self.queue, 1, -1 do
        local row = self.queue[i]
        if row.key:sub(1, 2) == kind .. ":" then
            self.lookup[row.key] = nil
            table.remove(self.queue, i)
        end
    end
    if #self.queue + #pages > 90 then return false end
    local revision = R:NextRevision()
    for i = 1, #pages do
        local page = priority and (#pages - i + 1) or i
        local message = string.format("S|%s|%.0f|%d|%d|%s|%s", kind, revision, page, #pages, header or "", pages[page])
        self:Queue(message, kind .. ":" .. page, priority)
    end
    return true
end

function N:SendNext()
    if #self.queue == 0 or not R:InGuild() or not R.commReady then return end
    if R:Read(IsInInstance) == true or R:Read(InCombatLockdown) == true then return end
    local now = R:Clock()
    if now - self.lastSend < 1.5 then return end
    local row = self.queue[1]
    local expired = now - row.at > 600
    if not expired then
        if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
        self.lastSend = now
        local ok, outcome = pcall(C_ChatInfo.SendAddonMessage, R.prefix, row.text, "GUILD")
        if not ok or (outcome ~= 0 and outcome ~= true) then
            row.tries = row.tries + 1
            self.lastSend = now + 3
            if row.tries < 6 then return end
            self.errors = self.errors + 1
        end
    end
    table.remove(self.queue, 1)
    self.lookup[row.key] = nil
end

local function records(payload)
    local result = {}
    if payload == "" then return result end
    if payload:sub(1, 1) == "," or payload:sub(-1) == "," or payload:find(",,", 1, true) then return nil end
    for record in payload:gmatch("[^,]+") do result[#result + 1] = record end
    return result
end

function N:Snapshot(peer, message)
    local kind, revision, index, total, header, payload =
        message:match("^S|([QRB])|(%d+)|(%d+)|(%d+)|([^|]*)|([^|]*)$")
    revision, index, total = tonumber(revision), tonumber(index), tonumber(total)
    if not R:SafeNumber(revision, 1, 9007199254740991) or not index or not total or
        index < 1 or total < 1 or total > MAX_PAGES or index > total or #payload > 170 then return end
    if kind == "B" and total > 5 then return end
    if kind == "Q" and not header:match("^%d+:%d+:%d+$") then return end
    if kind ~= "Q" and header ~= "" then return end
    peer.revisions = peer.revisions or {}
    if revision <= (peer.revisions[kind] or 0) then return end
    peer.assemblies = peer.assemblies or {}
    local assembly = peer.assemblies[kind]
    if assembly and revision < assembly.rev then return end
    if not assembly or assembly.rev ~= revision or R:Clock() - assembly.started > 180 then
        assembly = { rev = revision, started = R:Clock(), total = total, header = header, parts = {} }
        peer.assemblies[kind] = assembly
    end
    if assembly.total ~= total or assembly.header ~= header then return end
    assembly.parts[index] = payload
    for i = 1, total do if assembly.parts[i] == nil then return end end
    local all = {}
    for i = 1, total do
        local page = records(assembly.parts[i])
        if not page then return end
        for _, record in ipairs(page) do all[#all + 1] = record end
    end
    local valid = false
    if kind == "Q" then
        local map, x, y = header:match("^(%d+):(%d+):(%d+)$")
        map, x, y = tonumber(map), tonumber(x), tonumber(y)
        if not R:SafeNumber(map, 0, 999999) or not R:SafeNumber(x, 0, 99) or
            not R:SafeNumber(y, 0, 99) or (x > 9 and x ~= 99) or (y > 9 and y ~= 99) then return end
        local ids = {}
        if #all > 300 then return end
        for _, record in ipairs(all) do
            local id = record:match("^%d+$") and tonumber(record)
            if not R:SafeNumber(id, 1, 9999999) then return end
            ids[id] = true
        end
        peer.map, peer.x, peer.y, peer.quests = map, x, y, ids
        peer.questSeen = R:Clock()
        R.Quests:FindMatches(peer.name, peer)
        valid = true
    elseif kind == "R" then
        local recipes = {}
        for _, record in ipairs(all) do
            local item, recipe = record:match("^(%d+):(%d+)$")
            item, recipe = tonumber(item), tonumber(recipe)
            if not R:SafeNumber(item, 1, 9999999) or not R:SafeNumber(recipe, 1, 9999999) then return end
            recipes[item] = recipe
        end
        peer.recipes, peer.recipeSeen = recipes, R:Clock()
        valid = true
    elseif kind == "B" then
        valid = R.Bounties:Receive(peer.name, revision, all)
    end
    if valid then
        peer.revisions[kind] = revision
        peer.assemblies[kind] = nil
    end
end

function N:Receive(message, channel, sender)
    if channel ~= "GUILD" or not R:InGuild() or R:IsSecret(message) or
        type(message) ~= "string" or #message > 255 then return end
    local key = R:NameKey(sender)
    if not key or key == R:NameKey(R:UnitName("player")) or not R:IsMember(key) then return end
    if message ~= "H" and message:sub(1, 2) ~= "S|" and message:sub(1, 2) ~= "V|" then return end
    local peer = R.peers[key] or { recipes = {}, name = R:CleanName(sender), received = 0, window = R:Clock() }
    R.peers[key] = peer
    if R:Clock() - peer.window >= 60 then peer.window, peer.received = R:Clock(), 0 end
    peer.received = peer.received + 1
    if peer.received > 120 then return end
    peer.lastSeen = R:Clock()
    if message == "H" then
        if R:Clock() - self.lastReply >= 120 then
            self.lastReply = R:Clock()
            if C_Timer and C_Timer.After then
                C_Timer.After(2 + math.random(0, 8), function() R:Sync(false) end)
            end
        end
    elseif message:sub(1, 2) == "V|" then
        R.PvP:Receive(peer.name, message)
    else
        self:Snapshot(peer, message)
    end
end

function N:PrunePeers()
    local now = R:Clock()
    for key, peer in pairs(R.peers) do
        if now - (peer.lastSeen or 0) > 2400 or not R:IsMember(key) then R.peers[key] = nil end
    end
end
