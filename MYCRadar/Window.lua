local _, R = ...
R.Window = { tab = "pvp", metric = "lifetime", questView = "quests", page = 1, rows = {} }
local W = R.Window
local PAGE_SIZE = 6
local accent = { 0.22, 0.84, 0.75 }

local function label(parent, font, x, y, text)
    local f = parent:CreateFontString(nil, "OVERLAY", font)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetJustifyH("LEFT")
    f:SetText(text or "")
    return f
end

local function button(parent, text, width, x, y, action)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 21)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b.caption = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.caption:SetPoint("CENTER")
    b.caption:SetWidth(width - 4)
    b.caption:SetWordWrap(false)
    b.caption:SetText(text)
    function b:Paint()
        local enabled = self:IsEnabled()
        self:SetBackdropColor(self.hover and 0.10 or 0.06, self.hover and 0.14 or 0.08, self.hover and 0.15 or 0.09, 1)
        if self.selected then
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.75)
            self.caption:SetTextColor(accent[1], accent[2], accent[3])
        else
            self:SetBackdropBorderColor(0.17, 0.21, 0.23, 0.6)
            local brightness = enabled and 0.82 or 0.35
            self.caption:SetTextColor(brightness, brightness, brightness)
        end
    end
    function b:SetSelected(selected) self.selected = selected; self:Paint() end
    b:SetScript("OnEnter", function() b.hover = true; b:Paint() end)
    b:SetScript("OnLeave", function() b.hover = false; b:Paint() end)
    b:SetScript("OnEnable", function() b:Paint() end)
    b:SetScript("OnDisable", function() b:Paint() end)
    b:SetScript("OnClick", action)
    b:Paint()
    return b
end

local function whisper(name)
    if name and name ~= "You" and ChatFrame_SendTell then ChatFrame_SendTell(name) end
end

function W:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "MYCRadarWindow", UIParent, "BackdropTemplate")
    self.frame = f
    f:Hide()
    f:SetSize(390, 340)
    f:SetPoint("CENTER")
    local position = R.db.settings.window
    if type(position) == "table" and R:SafeNumber(position.x, -10000, 10000) and R:SafeNumber(position.y, -10000, 10000) then
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
    end
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local x, y = f:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        if x and y and parentX and parentY then R.db.settings.window = { x = x - parentX, y = y - parentY } end
    end)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.035, 0.045, 0.052, 0.98)
    f:SetBackdropBorderColor(0.19, 0.24, 0.26, 1)
    label(f, "GameFontNormal", 14, -13, "|cff37d6c0MYC|r")
    self.subtitle = label(f, "GameFontDisableSmall", 14, -32)
    self.subtitle:SetWidth(345)
    self.subtitle:SetWordWrap(false)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    UISpecialFrames[#UISpecialFrames + 1] = "MYCRadarWindow"

    self.tabs = {}
    for i, tab in ipairs({
        { "pvp", "PvP" }, { "bounties", "Bounties" }, { "quests", "Quests" }, { "crafters", "Crafters" },
    }) do
        local key = tab[1]
        self.tabs[key] = button(f, tab[2], 84, 14 + (i - 1) * 93, -52, function() W:Show(key) end)
    end
    self.metrics = {}
    for i, metric in ipairs({
        { "lifetime", "Lifetime HKs" }, { "undeadPaladins", "Undead paladins" }, { "points", "Bounty points" },
    }) do
        local key = metric[1]
        self.metrics[key] = button(f, metric[2], 114, 14 + (i - 1) * 124, -83, function()
            W.metric, W.page = key, 1
            W:Refresh()
        end)
    end
    self.hint = label(f, "GameFontHighlightSmall", 14, -85)
    self.hint:SetWidth(362)
    self.hint:SetWordWrap(false)
    self.addTarget = button(f, "Add target", 107, 269, -83, function()
        local _, message = R.Bounties:AddUnit("target")
        R:Chat(message)
        W:Refresh()
    end)
    self.addTarget:SetScript("OnEnter", function(b)
        b.hover = true; b:Paint()
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Add target", accent[1], accent[2], accent[3])
        GameTooltip:AddLine(b.detail or "Select a Horde player first.", 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    self.addTarget:SetScript("OnLeave", function(b) b.hover = false; b:Paint(); GameTooltip:Hide() end)
    self.questViews = {}
    for i, view in ipairs({ { "quests", "Shared quests" }, { "legacy", "Legacy goals" } }) do
        local key = view[1]
        self.questViews[key] = button(f, view[2], 114, 14 + (i - 1) * 124, -83, function()
            W.questView, W.page = key, 1
            W.search:SetText("")
            W:Refresh()
        end)
    end
    self.legacyCount = label(f, "GameFontDisableSmall", 262, -89)
    self.legacyCount:SetWidth(114)
    self.legacyCount:SetWordWrap(false)
    self.heading = label(f, "GameFontDisableSmall", 19, -114)
    self.heading:SetWidth(211)
    self.rightHeading = label(f, "GameFontDisableSmall", 239, -114)
    self.rightHeading:SetWidth(132)
    self.rightHeading:SetJustifyH("RIGHT")
    self.empty = label(f, "GameFontHighlightSmall", 26, -182)
    self.empty:SetWidth(338)
    self.empty:SetJustifyH("CENTER")
    for i = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(362, 23)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -130 - (i - 1) * 24)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.left = label(row, "GameFontHighlightSmall", 5, -6)
        row.left:SetWidth(211)
        row.left:SetWordWrap(false)
        row.right = label(row, "GameFontHighlightSmall", 225, -6)
        row.right:SetWidth(132)
        row.right:SetWordWrap(false)
        row.right:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function()
            if not row.data then return end
            if W.tab == "bounties" then
                W.input:SetText(row.data.name)
                W.input:ClearFocus()
            else
                whisper(row.data.contact)
            end
        end)
        row:SetScript("OnEnter", function()
            local data = row.data
            if not data then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            if data.itemID and GameTooltip.SetItemByID then GameTooltip:SetItemByID(data.itemID) end
            GameTooltip:AddLine(data.tooltipTitle or data.name or data.left, accent[1], accent[2], accent[3])
            if data.detail then GameTooltip:AddLine(data.detail, 0.85, 0.85, 0.85, true) end
            if data.contact then GameTooltip:AddLine("Click to whisper " .. data.contact, 0.6, 0.8, 0.75, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.rows[i] = row
    end

    self.previous = button(f, "<", 22, 14, -280, function() W.page = math.max(1, W.page - 1); W:Refresh() end)
    self.next = button(f, ">", 22, 90, -280, function() W.page = W.page + 1; W:Refresh() end)
    self.pageLabel = label(f, "GameFontDisableSmall", 44, -286)
    self.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    self.search:SetSize(205, 21)
    self.search:SetPoint("TOPLEFT", f, "TOPLEFT", 146, -280)
    self.search:SetAutoFocus(false)
    self.search:SetMaxBytes(80)
    self.search:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    self.search:SetScript("OnTextChanged", function() W.page = 1; W:Refresh() end)
    self.search.placeholder = label(self.search, "GameFontDisableSmall", 3, -5, "Search")
    self.clearSearch = button(f, "x", 20, 356, -280, function() W.search:SetText(""); W.search:ClearFocus() end)

    self.input = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    self.input:SetSize(205, 21)
    self.input:SetPoint("TOPLEFT", f, "TOPLEFT", 19, -311)
    self.input:SetAutoFocus(false)
    self.input:SetMaxBytes(512)
    self.input.placeholder = label(self.input, "GameFontDisableSmall", 3, -5, "Full name or player link")
    self.input:SetScript("OnTextChanged", function() W:Refresh() end)
    self.input:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    self.input:SetScript("OnEnterPressed", function() W:ChangeBounty(false) end)
    self.add = button(f, "+", 32, 231, -311, function() W:ChangeBounty(false) end)
    self.remove = button(f, "Remove mine", 107, 269, -311, function() W:ChangeBounty(true) end)
    self.footer = label(f, "GameFontDisableSmall", 14, -313)
    self.footer:SetWidth(362)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) W.page = W.page + (delta > 0 and -1 or 1); W:Refresh() end)
    f:SetScript("OnHide", function()
        W.input:ClearFocus()
        W.search:ClearFocus()
        GameTooltip:Hide()
    end)
end

function W:ChangeBounty(remove)
    local name = self.input:GetText()
    local ok, message
    if remove then ok, message = R.Bounties:Remove(name) else ok, message = R.Bounties:Add(name) end
    R:Chat(message)
    if ok then self.input:SetText("") end
    self.input:ClearFocus()
    self:Refresh()
end

function W:Data()
    local rows = {}
    if self.tab == "pvp" then
        for rank, row in ipairs(R.PvP:Leaderboard(self.metric)) do
            rows[#rows + 1] = {
                name = row.name, left = rank .. ".  " .. row.name, right = tostring(row.value),
                contact = row.key ~= R:NameKey(R:UnitName("player")) and row.name or nil,
                detail = "Last shared " .. R:Age(math.max(0, R:Now() - row.updated)) .. " ago.",
            }
        end
    elseif self.tab == "bounties" then
        for _, row in ipairs(R.Bounties:List()) do
            local sighting = row.sighting
            local seconds = sighting and math.max(0, math.floor(R:ServerNow() - sighting.observed)) or 0
            local area = sighting and R.Bounties:SightingArea(sighting)
            local witness = sighting and (sighting.witnessKey == R:NameKey(R:UnitName("player")) and "You" or sighting.witness)
            rows[#rows + 1] = {
                name = row.name, left = row.name,
                right = row.nearby and "|cffff8a45Nearby|r" or
                    (sighting and (seconds .. "s · " .. area) or
                    (row.claimed and "|cff888888Claimed today|r" or (row.own and "10 pts / yours" or "10 pts"))),
                detail = "Listed by " .. table.concat(row.authors, ", ") ..
                    ". 10 points for honor credit or your confirmed kill, once per victim per UTC day." ..
                    (row.claimed and " You already earned this reward today." or "") ..
                    (sighting and ("\nLast sighting: " .. seconds .. " seconds ago. Witness: " .. witness ..
                        ". Observer area: " .. area .. (sighting.x ~= 99 and sighting.y ~= 99 and
                        (" (map grid " .. (sighting.x + 1) .. ", " .. (sighting.y + 1) .. " of 10 × 10)") or "") ..
                        ". The target may have moved or be on another layer.") or "") ..
                    " Click to select the name.",
            }
        end
    elseif self.tab == "quests" and self.questView == "legacy" then
        rows = R.Legacy:Matches()
    elseif self.tab == "quests" then
        local q = R.Quests
        for key, peer in pairs(R.peers) do
            if R:IsMember(key) and peer.questSeen and R:Clock() - peer.questSeen < 420 and peer.map == q.map then
                for id in pairs(peer.quests or {}) do
                    if q.own[id] then
                        local near = q.x ~= 99 and peer.x ~= 99 and q.y ~= 99 and peer.y ~= 99 and
                            math.abs(q.x - peer.x) <= 1 and math.abs(q.y - peer.y) <= 1
                        rows[#rows + 1] = {
                            name = peer.name, left = q.title[id] or ("Quest #" .. id),
                            right = peer.name, contact = peer.name,
                            tooltipTitle = q.title[id] or ("Quest #" .. id),
                            detail = peer.name .. (near and " has this quest in your map area." or " has this quest in your zone."),
                        }
                    end
                end
            end
        end
    else
        local ownCrafts, items = R.Professions:AllCrafts(), {}
        for item in pairs(ownCrafts) do items[item] = true end
        for key, peer in pairs(R.peers) do
            if R:IsMember(key) and peer.recipeSeen and R:Clock() - peer.recipeSeen < 2100 then
                for item in pairs(peer.recipes or {}) do items[item] = true end
            end
        end
        for itemID in pairs(items) do
            local crafters = R.Professions:GetCrafters(itemID, ownCrafts) or {}
            if #crafters > 0 then
                local name = C_Item and R:Read(C_Item.GetItemNameByID, itemID)
                if R:IsSecret(name) or type(name) ~= "string" then name = "Item #" .. itemID end
                local contact
                for _, crafter in ipairs(crafters) do if crafter ~= "You" then contact = crafter; break end end
                rows[#rows + 1] = {
                    name = name, left = name, right = table.concat(crafters, ", "), itemID = itemID,
                    contact = contact, detail = "Known crafters: " .. table.concat(crafters, ", "),
                }
            end
        end
    end
    if self.tab ~= "pvp" and self.tab ~= "bounties" then
        table.sort(rows, function(a, b)
            if a.left == b.left then return a.right < b.right end
            return a.left < b.left
        end)
    end
    local search = (self.search:GetText() or ""):lower():match("^%s*(.-)%s*$")
    if search ~= "" then
        local filtered = {}
        for _, row in ipairs(rows) do
            if (row.left .. " " .. row.right .. " " .. (row.tooltipTitle or "") .. " " ..
                (row.itemID or "")):lower():find(search, 1, true) then
                filtered[#filtered + 1] = row
            end
        end
        return filtered
    end
    return rows
end

function W:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local guild = R.guildKey and R.guildKey:match("^(.-)@") or "Join your guild to use MYC."
    self.subtitle:SetText(R:IsEnabled() and guild or "Disabled. /myc on to resume.")
    self.frame:SetSize(390, self.tab == "bounties" and 374 or 340)
    for key, tab in pairs(self.tabs) do tab:SetSelected(key == self.tab) end
    for key, metric in pairs(self.metrics) do
        metric:SetShown(self.tab == "pvp")
        metric:SetSelected(key == self.metric)
    end
    for key, view in pairs(self.questViews) do
        view:SetShown(self.tab == "quests")
        view:SetSelected(self.questView == key)
    end
    self.legacyCount:SetShown(self.tab == "quests" and self.questView == "legacy")
    self.legacyCount:SetText((R.Legacy.tracked or 0) .. " tracked")
    self.hint:SetShown(self.tab ~= "pvp" and self.tab ~= "quests")
    local own, count = R.Bounties:Own() or {}, 0
    for _ in pairs(own) do count = count + 1 end
    self.hint:SetWidth(self.tab == "bounties" and 245 or 362)
    self.hint:SetText(self.tab == "bounties" and ("Your bounties: " .. count .. "/5") or
        (self.tab == "crafters" and "Open profession books to share. Click to whisper." or
        "Shared unfinished quests in your zone. Click to whisper."))
    local targetName, targetMessage = R.Bounties:UnitNameForBounty("target")
    local targetKey = R:NameKey(targetName)
    self.addTarget:SetShown(self.tab == "bounties")
    self.addTarget:SetEnabled(targetKey ~= nil and not own[targetKey] and count < 5)
    self.addTarget.detail = targetName and ("Add " .. targetName .. ". The full name is copied exactly.") or targetMessage
    if targetKey and own[targetKey] then self.addTarget.detail = targetName .. " is already on your list." end
    if count >= 5 then self.addTarget.detail = "Your five bounties are full. Remove one to add another." end
    local inputKey = R:NameKey(R.Bounties:InputName(self.input:GetText()))
    self.add:SetEnabled(inputKey ~= nil and not own[inputKey] and count < 5)
    self.remove:SetEnabled(inputKey ~= nil and own[inputKey] ~= nil)
    self.input.placeholder:SetShown(self.input:GetText() == "")
    self.search.placeholder:SetShown(self.search:GetText() == "")
    self.clearSearch:SetEnabled(self.search:GetText() ~= "")
    for _, control in ipairs({ self.input, self.add, self.remove }) do control:SetShown(self.tab == "bounties") end
    self.heading:SetText(self.tab == "pvp" and "GUILD MEMBER" or
        (self.tab == "bounties" and "HORDE CHARACTER" or (self.tab == "crafters" and "ITEM" or "QUEST")))
    self.rightHeading:SetText(self.tab == "pvp" and (self.metric == "points" and "POINTS" or
        (self.metric == "undeadPaladins" and "KILLS" or "HONORABLE KILLS")) or
        (self.tab == "bounties" and "SIGHTING / REWARD" or (self.tab == "crafters" and "CRAFTERS" or "GUILDMATE")))
    if self.tab == "quests" and self.questView == "legacy" then self.heading:SetText("LEGACY OBJECTIVE") end
    local data = self:Data()
    local pages = math.max(1, math.ceil(#data / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page, pages))
    self.pageLabel:SetText(self.page .. " / " .. pages)
    self.previous:SetEnabled(self.page > 1)
    self.next:SetEnabled(self.page < pages)
    for i, row in ipairs(self.rows) do
        row.data = data[(self.page - 1) * PAGE_SIZE + i]
        row:SetShown(row.data ~= nil)
        if row.data then
            row.left:SetText(row.data.left)
            row.right:SetText(row.data.right)
        end
    end
    self.empty:SetShown(#data == 0)
    self.empty:SetText(self.search:GetText():match("%S") and "No matches. Try another name or item." or
        (self.tab == "pvp" and "No shared PvP totals yet." or
        (self.tab == "bounties" and "No bounties. Add a full Horde name below." or
        (self.tab == "crafters" and "No recipes shared yet. Open your profession books." or
        (self.questView == "legacy" and
            (not R.Legacy:Available() and "Legacy tracking is unavailable on this client." or
            (not next(R.Legacy.own) and "Track a Legacy challenge in WoW to share your goals." or
            "No guildmates share your unfinished Legacy objectives yet.")) or "No shared quests in your zone yet."))))
    )
    self.footer:ClearAllPoints()
    self.footer:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 14, self.tab == "bounties" and -347 or -313)
    local named = #R.PvP:HonorFormats() > 0 and not R.failedEvents.CHAT_MSG_COMBAT_HONOR_GAIN
    local personal = not R.failedEvents.PARTY_KILL
    if self.tab == "pvp" then
        self.footer:SetText(self.metric == "lifetime" and "WoW lifetime totals. Hover for the last shared update." or
            ((named or personal) and "Honor credit + readable personal kills. No honor required." or
                "Kill credit is unavailable on this client."))
    elseif self.tab == "bounties" then
        self.footer:SetText((named or personal) and "Sightings expire after 90s. Hover for witness and reward." or
            "Nearby alerts work; kill credit is unavailable on this client.")
    elseif self.tab == "quests" and self.questView == "legacy" then
        self.footer:SetText("Track challenges in WoW's Legacy window. Click to whisper.")
    else
        self.footer:SetText("Guildmates need MYC. /myc sync to refresh.")
    end
end

function W:Show(tab)
    self:Create()
    if tab then
        self.tab, self.page = tab, 1
        self.search:SetText("")
        self.search:ClearFocus()
    end
    self.frame:Show()
    R.PvP:Broadcast(false)
    if self.tab == "quests" then R.Legacy:Broadcast(false) end
    self:Refresh()
end

function W:Toggle()
    self:Create()
    if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end
