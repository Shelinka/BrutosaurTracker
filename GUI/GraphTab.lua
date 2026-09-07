local ADDON_NAME, BT = ...
local GUI = BT.GUI

function GUI.CreateGraphTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local totalLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    totalLabel:SetPoint("TOPLEFT", 16, -16)
    panel.totalLabel = totalLabel

    local subLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subLabel:SetPoint("TOPLEFT", totalLabel, "BOTTOMLEFT", 0, -4)
    panel.subLabel = subLabel

    local sinceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sinceLabel:SetPoint("TOPLEFT", subLabel, "BOTTOMLEFT", 0, -2)
    panel.sinceLabel = sinceLabel

    local dropdown = GUI.CreateSharedRangeDropdown(panel, function()
        panel.Refresh()
    end)
    dropdown:SetPoint("TOPRIGHT", -4, -8)
    panel.dropdown = dropdown

    local graphFrame = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
    graphFrame:SetPoint("TOPLEFT", 16, -78)
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

        sinceLabel:SetText("Tracking since " .. date("%b %d, %Y", BT:GetTrackingSinceDate()))

        local days = BT.db.settings.graphRangeDays or 7
        local points, windowStart, windowEnd = BT:GetGoldTimeSeries(days)

        local goal = BT:GetGoldGoal()
        graph:SetData(points, goal > 0 and goal or nil, windowStart, windowEnd)
        emptyLabel:SetShown(#points == 0)

        dropdown:RefreshText()
    end
    panel.Refresh = Refresh

    panel:SetScript("OnShow", Refresh)
    return panel
end
