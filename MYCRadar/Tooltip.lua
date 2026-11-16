local _, R = ...
R.Tooltip = {}

function R.Tooltip:OnItem(tooltip, data)
    if not R:IsEnabled() or not R:InGuild() or type(data) ~= "table" then return end
    local itemID = R:SafeNumber(data.id, 1, 9999999)
    if not itemID or not tooltip or not tooltip.AddLine then return end
    local crafters = R.Professions:GetCrafters(itemID)
    if not crafters or #crafters == 0 then return end
    if crafters and #crafters > 0 then
        local shown = {}
        for i = 1, math.min(3, #crafters) do shown[#shown + 1] = crafters[i] end
        local rest = #crafters > 3 and " +" .. (#crafters - 3) or ""
        tooltip:AddLine("|cff37d6c0MYC craft:|r " .. table.concat(shown, ", ") .. rest, 1, 1, 1)
    end
    if tooltip.Show then tooltip:Show() end
end

function R.Tooltip:Install()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        -- The modern post-call is used rather than removed OnTooltipSetItem hooks.
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            R.Tooltip:OnItem(tooltip, data)
        end)
    end
end
