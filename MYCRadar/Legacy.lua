local _, R = ...
R.Legacy = { own = {}, lastBroadcast = -9999 }
local L = R.Legacy
local MAX_OBJECTIVES = 128

function L:Invalidate()
    self.own, self.lastSignature, self.lastBroadcast, self.pending, self.tracked = {}, nil, -9999, false, 0
end

function L:Available()
    return C_ContentTracking and type(C_ContentTracking.GetTrackedIDs) == "function" and
        Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement ~= nil and
        C_Traits and type(C_Traits.GetTraitCurrencyForAchievement) == "function" and
        type(GetAchievementInfo) == "function" and type(GetAchievementNumCriteria) == "function" and
        type(GetAchievementCriteriaInfo) == "function"
end

local function text(value)
    return not R:IsSecret(value) and type(value) == "string" and value ~= "" and value or nil
end

function L:Snapshot()
    local own, records = {}, {}
    self.tracked = 0
    if not self:Available() then return own, records end
    local ids = R:Read(C_ContentTracking.GetTrackedIDs, Enum.ContentTrackingType.Achievement)
    if type(ids) ~= "table" or R:IsSecret(ids) then return own, records end
    local sorted, seen = {}, {}
    for _, id in ipairs(ids) do
        if R:SafeNumber(id, 1, 9999999) and id % 1 == 0 and not seen[id] then
            sorted[#sorted + 1], seen[id] = id, true
        end
    end
    table.sort(sorted)
    local currency = Constants and Constants.LegacyConsts and Constants.LegacyConsts.LEGACY_POINTS_TRAIT_CURRENCY_ID or 4225
    for n = 1, math.min(10, #sorted) do
        local id = sorted[n]
        local points = R:Read(C_Traits.GetTraitCurrencyForAchievement, currency, id)
        local ok, _, name, _, completed, _, _, _, _, _, _, _, _, earnedByMe = pcall(GetAchievementInfo, id)
        -- Legacy rewards are account-wide; account completion alone must not hide a character's goal.
        if ok and text(name) and R:SafeNumber(points, 1, 999999) and
            not R:IsSecret(earnedByMe) and earnedByMe ~= true and
            not R:IsSecret(completed) then
            self.tracked = self.tracked + 1
            local total = R:Read(GetAchievementNumCriteria, id)
            if R:SafeNumber(total, 0, 64) and total % 1 == 0 then
                for criterionIndex = 1, math.max(1, total) do
                    local index = total == 0 and 0 or criterionIndex
                    local label, done, quantity, required
                    if total == 0 then
                        label, done, quantity, required = name, false, 0, 1
                    else
                        local good, criterion, _, finished, current, needed = pcall(GetAchievementCriteriaInfo, id, index)
                        if good then label, done, quantity, required = text(criterion), finished, current, needed end
                    end
                    if label and not R:IsSecret(done) and done == false and
                        R:SafeNumber(quantity, 0, 1000000000000) and
                        R:SafeNumber(required, 1, 1000000000000) and quantity < required and
                        quantity % 1 == 0 and required % 1 == 0 and #records < MAX_OBJECTIVES then
                        local key = string.format("%d:%d", id, index)
                        own[key] = { id = id, title = name, label = label, quantity = quantity, required = required }
                        records[#records + 1] = string.format("%d:%d:%.0f:%.0f", id, index, quantity, required)
                    end
                end
            end
        end
    end
    return own, records
end

function L:Broadcast(force)
    if not R:InGuild() then return end
    local own, records = self:Snapshot()
    self.own = own
    local signature, now = table.concat(records, ","), R:Clock()
    if now - self.lastBroadcast < 20 then return end
    if force or signature ~= self.lastSignature or now - self.lastBroadcast >= 300 then
        if R.Net:QueueSnapshot("L", records, "", true) then
            self.lastSignature, self.lastBroadcast = signature, now
        end
    end
end

function L:Soon()
    if self.pending or not C_Timer or not C_Timer.After then return end
    self.pending = true
    C_Timer.After(3, function() L.pending = false; L:Broadcast(false) end)
end

function L:Receive(peer, records)
    if #records > MAX_OBJECTIVES then return false end
    local goals = {}
    for _, record in ipairs(records) do
        local id, index, quantity, required = record:match("^(%d+):(%d+):(%d+):(%d+)$")
        id, index, quantity, required = tonumber(id), tonumber(index), tonumber(quantity), tonumber(required)
        if not R:SafeNumber(id, 1, 9999999) or not R:SafeNumber(index, 0, 64) or
            not R:SafeNumber(quantity, 0, 1000000000000) or
            not R:SafeNumber(required, 1, 1000000000000) or quantity >= required then return false end
        local key = string.format("%d:%d", id, index)
        if goals[key] then return false end
        goals[key] = { quantity = quantity, required = required }
    end
    peer.legacy, peer.legacySeen = goals, R:Clock()
    return true
end

function L:Matches()
    local rows = {}
    for member, peer in pairs(R.peers) do
        if R:IsMember(member) and peer.legacySeen and R:Clock() - peer.legacySeen < 420 then
            for key, other in pairs(peer.legacy or {}) do
                local own = self.own[key]
                if own and own.required == other.required then
                    rows[#rows + 1] = {
                        name = peer.name, contact = peer.name, left = own.label, right = peer.name,
                        tooltipTitle = own.title .. " — " .. own.label,
                        detail = string.format("Legacy goal. You: %.0f/%.0f. %s: %.0f/%.0f. Last shared: %s.",
                            own.quantity, own.required, peer.name, other.quantity, other.required,
                            R:Age(R:Clock() - peer.legacySeen)),
                    }
                end
            end
        end
    end
    return rows
end
