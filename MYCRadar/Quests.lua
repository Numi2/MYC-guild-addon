local _, R = ...
R.Quests = { own = {}, title = {}, lastSignature = nil, lastBroadcast = -9999, pending = false }
local Q = R.Quests

function Q:Invalidate()
    self.lastSignature = nil
    self.lastBroadcast = -9999
    self.pending = false
    self.own, self.title, self.map = {}, {}, nil
end

function Q:Area()
    local map, x, y = 0, 99, 99
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, current = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and R:SafeNumber(current, 1, 999999) then map = current end
        if map > 0 and C_Map.GetPlayerMapPosition then
            local success, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
            if success and pos and pos.GetXY then
                local works, px, py = pcall(pos.GetXY, pos)
                if works and R:SafeNumber(px, 0, 1) and R:SafeNumber(py, 0, 1) then
                    x = math.min(9, math.floor(px * 10))
                    y = math.min(9, math.floor(py * 10))
                end
            end
        end
    end
    return map, x, y
end

function Q:Snapshot()
    local map, x, y = self:Area()
    local ids, own, titles = {}, {}, {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local ok, total = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and R:SafeNumber(total, 0, 3000) then
            for i = 1, total do
                local success, info = pcall(C_QuestLog.GetInfo, i)
                if success and type(info) == "table" and not info.isHeader and not info.isHidden and
                    R:SafeNumber(info.questID, 1, 9999999) then
                    local completed = false
                    if C_QuestLog.IsComplete then
                        local good, result = pcall(C_QuestLog.IsComplete, info.questID)
                        completed = not good or R:IsSecret(result) or result == true
                    end
                    if not completed and not own[info.questID] then
                        own[info.questID] = true
                        ids[#ids + 1] = info.questID
                        if not R:IsSecret(info.title) and type(info.title) == "string" then titles[info.questID] = info.title end
                    end
                end
            end
        end
    end
    table.sort(ids)
    return map, x, y, ids, own, titles
end

function Q:Broadcast(force)
    if not R:InGuild() then return end
    local map, x, y, ids, own, titles = self:Snapshot()
    self.own, self.title, self.map, self.x, self.y = own, titles, map, x, y
    local signature = map .. ":" .. x .. ":" .. y .. ":" .. table.concat(ids, ",")
    local now = R:Clock()
    -- Cap travel updates at once per 20 s, even if quest/map events are noisy.
    if now - self.lastBroadcast < 20 then return end
    if force or signature ~= self.lastSignature or now - self.lastBroadcast > 300 then
        local records = {}
        for _, id in ipairs(ids) do records[#records + 1] = tostring(id) end
        R.Net:QueueSnapshot("Q", records, map .. ":" .. x .. ":" .. y, true)
        self.lastSignature = signature
        self.lastBroadcast = now
        self:RecheckMatches()
    end
end

function Q:Soon()
    if self.pending or not C_Timer or not C_Timer.After then return end
    self.pending = true
    C_Timer.After(3, function()
        Q.pending = false
        Q:Broadcast(false)
    end)
end

function Q:FindMatches(sender, peer)
    if not self.own or not peer.quests or not self.map or self.map == 0 or peer.map ~= self.map then return end
    local near = true
    if self.x ~= 99 and self.y ~= 99 and peer.x ~= 99 and peer.y ~= 99 then
        near = math.abs(self.x - peer.x) <= 1 and math.abs(self.y - peer.y) <= 1
    end
    if not near then return end
    local bestID
    for id in pairs(peer.quests) do
        if self.own[id] and (not bestID or id < bestID) then bestID = id end
    end
    if not bestID then return end
    local title = self.title[bestID] or (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(bestID)) or "a shared quest"
    if R:IsSecret(title) or type(title) ~= "string" or title == "" then title = "a shared quest" end
    local detail = R:CleanName(sender) .. " is in your zone"
    if self.x ~= 99 and peer.x ~= 99 then detail = R:CleanName(sender) .. " is in your area" end
    R:Toast("Shared quest: " .. title:sub(1, 55), detail, "Q:" .. sender .. ":" .. bestID)
end

function Q:RecheckMatches()
    for _, peer in pairs(R.peers) do
        if peer.questSeen and R:Clock() - peer.questSeen < 420 then
            self:FindMatches(peer.name, peer)
        end
    end
end
