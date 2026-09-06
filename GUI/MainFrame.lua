local ADDON_NAME, BT = ...
local GUI = BT.GUI

local TABS = {
    { key = "graph", label = "Gold History", builder = "CreateGraphTab" },
    { key = "ledger", label = "Income / Spending", builder = "CreateLedgerTab" },
    { key = "sales", label = "Item Sales", builder = "CreateItemSalesTab" },
    { key = "goal", label = "Gold Goal", builder = "CreateGoalTab" },
    { key = "characters", label = "Characters", builder = "CreateCharactersTab" },
}

function BT:CreateMainFrame()
    if self.mainFrame then return self.mainFrame end

    local frame = CreateFrame("Frame", "BrutosaurTrackerMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(760, 480)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    tinsert(UISpecialFrames, "BrutosaurTrackerMainFrame")

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", 8, -6)
    icon:SetTexture(self.ICON)

    frame.TitleText:ClearAllPoints()
    frame.TitleText:SetPoint("LEFT", icon, "RIGHT", 6, 1)
    frame.TitleText:SetText("Brutosaur Tracker")

    -- tab bar
    local tabButtons = {}
    local panels = {}
    local lastTab

    local function SelectTab(key)
        for _, t in ipairs(TABS) do
            local shown = (t.key == key)
            panels[t.key]:SetShown(shown)
            if shown then
                tabButtons[t.key]:LockHighlight()
                tabButtons[t.key]:Disable()
            else
                tabButtons[t.key]:UnlockHighlight()
                tabButtons[t.key]:Enable()
            end
        end
        lastTab = key
    end

    local prevBtn
    for i, t in ipairs(TABS) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(140, 22)
        btn:SetText(t.label)
        if prevBtn then
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        else
            btn:SetPoint("TOPLEFT", 16, -32)
        end
        btn:SetScript("OnClick", function() SelectTab(t.key) end)
        tabButtons[t.key] = btn
        prevBtn = btn

        local panel = GUI[t.builder](frame)
        panel:SetPoint("TOPLEFT", 12, -64)
        panel:SetPoint("BOTTOMRIGHT", -12, 12)
        panel:Hide()
        panels[t.key] = panel
    end

    frame.SelectTab = SelectTab
    frame.RefreshAll = function()
        for _, t in ipairs(TABS) do
            if panels[t.key].Refresh then panels[t.key].Refresh() end
        end
    end

    frame:SetScript("OnShow", function()
        SelectTab(lastTab or "graph")
    end)

    self.mainFrame = frame
    return frame
end

function BT:ToggleMainFrame()
    local frame = self:CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
