local _, R = ...
R.Professions = { lastScan = -9999, lastBroadcast = -9999, pending = false }
local P = R.Professions

function P:AllCrafts()
    local db = R:CharGuildDB()
    if not db then return {} end
    local results = {}
    for _, profession in pairs(db.professions) do
        if type(profession) == "table" and type(profession.crafts) == "table" then
            for item, recipe in pairs(profession.crafts) do
                if R:SafeNumber(item, 1, 9999999) and R:SafeNumber(recipe, 1, 9999999) then
                    results[item] = recipe
                end
            end
        end
    end
    return results
end

function P:Scan()
    if not R:InGuild() then return end
    local t = C_TradeSkillUI
    if not t or not t.GetAllRecipeIDs or not t.GetRecipeInfo or not t.GetRecipeSchematic then return end
    -- Never index a linked guildmate's book or an NPC recipe list as your own.
    for _, method in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        local value = R:Read(t[method])
        if R:IsSecret(value) or value == true then return end
    end
    if t.IsTradeSkillReady then
        local ok, ready = pcall(t.IsTradeSkillReady)
        if not ok or not ready then return end
    end
    local ok, recipes = pcall(t.GetAllRecipeIDs)
    if not ok or type(recipes) ~= "table" or #recipes == 0 then return end
    local professionID
    if t.GetBaseProfessionInfo then
        local success, info = pcall(t.GetBaseProfessionInfo)
        if success and type(info) == "table" then professionID = info.professionID end
    end
    if not R:SafeNumber(professionID, 1, 9999999) and t.GetChildProfessionInfo then
        local success, info = pcall(t.GetChildProfessionInfo)
        if success and type(info) == "table" then professionID = info.professionID end
    end
    if not R:SafeNumber(professionID, 1, 9999999) then return end

    local crafts = {}
    for _, recipeID in ipairs(recipes) do
        if R:SafeNumber(recipeID, 1, 9999999) then
            local success, info = pcall(t.GetRecipeInfo, recipeID)
            if success and type(info) == "table" and info.learned == true and not info.disabled then
                local good, schematic = pcall(t.GetRecipeSchematic, recipeID, false)
                local itemID = good and type(schematic) == "table" and R:SafeNumber(schematic.outputItemID, 1, 9999999)
                if not itemID and t.GetRecipeItemLink then
                    local link = R:Read(t.GetRecipeItemLink, recipeID)
                    if not R:IsSecret(link) and type(link) == "string" then
                        itemID = R:SafeNumber(tonumber(link:match("item:(%d+)")), 1, 9999999)
                    end
                end
                if itemID then crafts[itemID] = recipeID end
            end
        end
    end
    local db = R:CharGuildDB()
    if not db then return end
    local old = db.professions[professionID]
    local changed = type(old) ~= "table" or type(old.crafts) ~= "table"
    if not changed then
        for item, recipe in pairs(crafts) do if old.crafts[item] ~= recipe then changed = true; break end end
        if not changed then for item in pairs(old.crafts) do if not crafts[item] then changed = true; break end end end
    end
    db.professions[professionID] = { crafts = crafts, updated = R:Now() }
    if changed then self:Broadcast(true) end
end

function P:Soon()
    if self.pending or not C_Timer or not C_Timer.After then return end
    self.pending = true
    C_Timer.After(1.5, function()
        P.pending = false
        if R:Clock() - P.lastScan >= 6 then
            P.lastScan = R:Clock()
            P:Scan()
        end
    end)
end

function P:Broadcast(force)
    if not R:InGuild() then return end
    if not force and R:Clock() - self.lastBroadcast < 1800 then return end
    local crafts = self:AllCrafts()
    local records = {}
    for item, recipe in pairs(crafts) do
        records[#records + 1] = item .. ":" .. recipe
    end
    table.sort(records)
    R.Net:QueueSnapshot("R", records, "", false)
    self.lastBroadcast = R:Clock()
end

function P:GetCrafters(itemID, ownCrafts)
    if not R:InGuild() then return nil end
    local names = {}
    if (ownCrafts or self:AllCrafts())[itemID] then names[#names + 1] = "You" end
    for key, peer in pairs(R.peers) do
        if peer.recipes and peer.recipes[itemID] and peer.recipeSeen and
            R:Clock() - peer.recipeSeen < 2100 and R:IsMember(key) then
            names[#names + 1] = R:CleanName(peer.name)
        end
    end
    table.sort(names)
    return names
end
