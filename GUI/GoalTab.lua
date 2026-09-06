local ADDON_NAME, BT = ...
local GUI = BT.GUI

function GUI.CreateGoalTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Gold Goal")

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    label:SetText("Target amount (gold):")

    local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    editBox:SetSize(140, 24)
    editBox:SetPoint("LEFT", label, "RIGHT", 12, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)

    local saveBtn = GUI.CreateTabButton(panel, "Set Goal", function()
        local goldValue = tonumber(editBox:GetText()) or 0
        BT:SetGoldGoal(goldValue * 10000)
        editBox:ClearFocus()
        panel.Refresh()
    end)
    saveBtn:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
    saveBtn:SetSize(90, 24)

    editBox:SetScript("OnEnterPressed", function() saveBtn:Click() end)

    -- progress display
    local progressBox = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
    progressBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -4, -24)
    progressBox:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    progressBox:SetHeight(120)

    local goalLine = progressBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    goalLine:SetPoint("TOPLEFT", 14, -14)

    local currentLine = progressBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentLine:SetPoint("TOPLEFT", goalLine, "BOTTOMLEFT", 0, -8)

    local remainingLine = progressBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    remainingLine:SetPoint("TOPLEFT", currentLine, "BOTTOMLEFT", 0, -12)

    local barBG = CreateFrame("StatusBar", nil, progressBox)
    barBG:SetPoint("BOTTOMLEFT", 14, 14)
    barBG:SetPoint("BOTTOMRIGHT", -14, 14)
    barBG:SetHeight(18)
    barBG:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBG:SetStatusBarColor(0.2, 0.85, 0.3)
    barBG:SetMinMaxValues(0, 1)

    local barBackdrop = barBG:CreateTexture(nil, "BACKGROUND")
    barBackdrop:SetAllPoints()
    barBackdrop:SetColorTexture(0, 0, 0, 0.5)

    local barText = barBG:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    barText:SetPoint("CENTER")

    local function Refresh()
        local goal, current, remaining = BT:GetGoalProgress()
        goalLine:SetText("Goal: " .. GUI.FormatMoney(goal))
        currentLine:SetText("Current total: " .. GUI.FormatMoney(current))

        if goal <= 0 then
            remainingLine:SetText("Set a goal above to start tracking progress.")
            barBG:SetValue(0)
            barText:SetText("")
        elseif remaining == 0 then
            remainingLine:SetText("|cff20d947Goal reached!|r")
            barBG:SetValue(1)
            barText:SetText("100%")
        else
            remainingLine:SetText("Still need: " .. GUI.FormatMoney(remaining))
            local pct = math.min(1, current / goal)
            barBG:SetValue(pct)
            barText:SetText(string.format("%.1f%%", pct * 100))
        end

        editBox:SetText(tostring(math.floor(goal / 10000)))
    end
    panel.Refresh = Refresh
    panel:SetScript("OnShow", Refresh)

    return panel
end
