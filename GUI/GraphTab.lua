local ADDON_NAME, BT = ...
local GUI = BT.GUI

local RANGE_OPTIONS = {
    { label = "Last 24 Hours", days = 1 },
    { label = "Last 7 Days", days = 7 },
    { label = "Last Month", days = 30 },
    { label = "Last Half a Year", days = 182 },
    { label = "Last Year", days = 365 },
    { label = "All Time", days = 3650 },
}

function GUI.CreateGraphTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local totalLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalLabel:SetPoint("TOPLEFT", 16, -16)
    panel.totalLabel = totalLabel

    local subLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subLabel:SetPoint("TOPLEFT", totalLabel, "BOTTOMLEFT", 0, -4)
    panel.subLabel = subLabel

    -- Range dropdown
    local dropdown = CreateFrame("Frame", "BrutosaurTrackerGraphRangeDropdown", panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPRIGHT", -4, -8)
    panel.dropdown = dropdown

    local graphFrame = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
    graphFrame:SetPoint("TOPLEFT", 16, -70)
    graphFrame:SetPoint("BOTTOMRIGHT", -16, 40)
    panel.graphFrame = graphFrame

    local graph = GUI.NewGraph(graphFrame, 10, 10)
    graph.area:SetPoint("TOPLEFT", 6, -6)
    graph.area:SetPoint("BOTTOMRIGHT", -6, 6)
    panel.graph = graph

    local emptyLabel = graphFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyLabel:SetPoint("CENTER")
    emptyLabel:SetText("Not enough history yet for this range - a point is recorded whenever your total gold changes.")
    emptyLabel:Hide()

    local function Refresh()
        local total = BT:GetTotalGold()
        totalLabel:SetText("Total Gold: " .. GUI.FormatMoney(total))

        local charCount = 0
        for _ in pairs(BT.db.characters) do charCount = charCount + 1 end
        subLabel:SetText(string.format("%d character%s tracked + live warband bank  (see the Characters tab for a breakdown)",
            charCount, charCount == 1 and "" or "s"))

        local days = BT.db.settings.graphRangeDays or 7
        local points = BT:GetGoldTimeSeries(days)

        local goal = BT:GetGoldGoal()
        graph:SetData(points, goal > 0 and goal or nil)
        emptyLabel:SetShown(#points < 2)
    end
    panel.Refresh = Refresh

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, opt in ipairs(RANGE_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.func = function()
                BT.db.settings.graphRangeDays = opt.days
                UIDropDownMenu_SetText(dropdown, opt.label)
                Refresh()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(dropdown, 130)
    for _, opt in ipairs(RANGE_OPTIONS) do
        if opt.days == (BT.db and BT.db.settings.graphRangeDays) then
            UIDropDownMenu_SetText(dropdown, opt.label)
        end
    end

    panel:SetScript("OnShow", Refresh)
    return panel
end
