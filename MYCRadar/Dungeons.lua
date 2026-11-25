local _, R = ...
R.Dungeons = {}
local D = R.Dungeons

-- Active quests with objectives inside these instances. IDs are from the
-- Forever quest records. Legacy criteria are resolved in the client by asset
-- (boss or instance ID), with the criterion name as an English fallback.
local dungeons = {
    {
        name = "The Deadmines", instance = 36, achievement = 64016,
        bossID = 639, boss = "Edwin VanCleef",
        quests = {
            [166] = "The Defias Brotherhood", [167] = "Oh Brother. . .",
            [168] = "Collecting Memories", [214] = "Red Silk Bandanas",
            [2040] = "Underground Assault", [92753] = "Destruction in Deadmines",
            [95140] = "Old Fire-Eye",
        },
    },
    {
        name = "City of Dalaran", instance = 2959, achievement = 62032,
        bossID = 246020, boss = "Shade of the Archmage",
        quests = {
            [92456] = "A Green Sample", [92457] = "Starving Arcane",
            [92458] = "Heart of Disruption", [92489] = "Power Overwhelming",
            [96984] = "Heart of Disruption", [96987] = "Opportunistic Education",
            [96988] = "Source of Power",
        },
    },
    {
        name = "The Drowned City", instance = 2970, achievement = 62032,
        bossID = 260243, boss = "Min'loth the Serpent",
        quests = {
            [95775] = "The Drowned City", [95776] = "The Only Good Brinescale...",
            [95787] = "Take Two With Water", [95788] = "Magics of the Drowned City",
            [95789] = "Shady Saltseers", [95791] = "The Saltseer Captain",
            [96774] = "Ancient Gurubashi Idol", [97130] = "Ancient Gurubashi Secrets",
        },
    },
}

local function legacyKey(dungeon)
    if type(GetAchievementCriteriaInfo) ~= "function" then return nil end
    local total = R:SafeNumber(R:Read(GetAchievementNumCriteria, dungeon.achievement), 1, 64)
    if not total then return nil end
    for i = 1, total do
        local ok, name, _, _, _, _, _, _, asset = pcall(GetAchievementCriteriaInfo, dungeon.achievement, i)
        if ok then
            asset = R:SafeNumber(asset, 1, 9999999)
            if asset == dungeon.bossID or asset == dungeon.instance or
                (not R:IsSecret(name) and name == dungeon.name) then
                return dungeon.achievement .. ":" .. i
            end
        end
    end
end

local function goalsFor(dungeon, key, quests, legacy)
    local questsNeeded = {}
    for id in pairs(dungeon.quests) do
        if quests and quests[id] then questsNeeded[#questsNeeded + 1] = id end
    end
    table.sort(questsNeeded)
    return questsNeeded, key and legacy and legacy[key] ~= nil or false
end

local function questTitle(dungeon, id)
    local title = R.Quests.title[id] or (C_QuestLog and R:Read(C_QuestLog.GetTitleForQuestID, id))
    if not R:IsSecret(title) and type(title) == "string" and title ~= "" then return title end
    return dungeon.quests[id]
end

function D:Best()
    if not R:InGuild() or not next(R.peers) then return nil end
    local now, best = R:Clock(), nil
    for _, dungeon in ipairs(dungeons) do
        local key = legacyKey(dungeon)
        local ownQuests, ownLegacy = goalsFor(dungeon, key, R.Quests.own, R.Legacy.own)
        if #ownQuests > 0 or ownLegacy then
            local people, unique, goalCount = {}, {}, 0
            local function add(name, quests, legacy)
                people[#people + 1] = { name = name, quests = quests, legacy = legacy }
                for _, id in ipairs(quests) do
                    if not unique[id] then unique[id], goalCount = true, goalCount + 1 end
                end
                if legacy and not unique[key] then unique[key], goalCount = true, goalCount + 1 end
            end
            add("You", ownQuests, ownLegacy)
            for member, peer in pairs(R.peers) do
                if R:IsMember(member) then
                    local quests = peer.questSeen and now - peer.questSeen < 420 and peer.quests
                    local legacy = peer.legacySeen and now - peer.legacySeen < 420 and peer.legacy
                    local needed, clear = goalsFor(dungeon, key, quests, legacy)
                    if #needed > 0 or clear then add(peer.name, needed, clear) end
                end
            end
            if #people >= 2 and goalCount >= 2 and
                (not best or #people > #best.people or (#people == #best.people and goalCount > best.goals)) then
                best = { dungeon = dungeon, people = people, goals = goalCount }
            end
        end
    end
    if not best then return nil end

    table.sort(best.people, function(a, b)
        if a.name == "You" then return b.name ~= "You" end
        return b.name ~= "You" and a.name < b.name
    end)
    local lines = {}
    for i = 1, math.min(10, #best.people) do
        local person = best.people[i]
        local reasons = {}
        for _, id in ipairs(person.quests) do reasons[#reasons + 1] = questTitle(best.dungeon, id) end
        if person.legacy then reasons[#reasons + 1] = "Legacy · Defeat " .. best.dungeon.boss end
        lines[#lines + 1] = person.name .. " — " .. table.concat(reasons, ", ")
    end
    if #best.people > 10 then lines[#lines + 1] = "+" .. (#best.people - 10) .. " more guildmates" end
    local others = #best.people - 1
    return {
        left = best.dungeon.name,
        right = "You + " .. others .. (others == 1 and " guildmate" or " guildmates"),
        tooltipTitle = best.dungeon.name .. " · One run",
        detail = table.concat(lines, "\n"),
        dungeon = true,
    }
end
