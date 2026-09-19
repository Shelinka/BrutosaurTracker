local ADDON_NAME, BT = ...
local GUI = BT.GUI

local ROW_HEIGHT = 22

StaticPopupDialogs["BRUTOSAURTRACKER_RESET_LEDGER"] = {
    text = "This will permanently delete all Income / Spending history.\nType Delete below to confirm.",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 20,
    OnShow = function(self)
        self.editBox:SetText("")
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local typed = self.editBox and self.editBox:GetText() or ""
        if typed == "Delete" then
            BT:ResetLedger()
            if BT.mainFrame and BT.mainFrame.RefreshAll then BT.mainFrame.RefreshAll() end
        else
            print("|cffff4040Brutosaur Tracker|r Reset cancelled - you must type \"Delete\" exactly.")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent().button1:Click()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function GUI.CreateLedgerTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local dropdown

    local resetBtn = GUI.CreateTabButton(panel, "Reset", function()
        StaticPopup_Show("BRUTOSAURTRACKER_RESET_LEDGER")
    end)
    resetBtn:SetSize(90, 24)
    resetBtn:SetPoint("TOPRIGHT", -4, -8)

    dropdown = GUI.CreateSharedRangeDropdown(panel, function() panel.Refresh() end)
    dropdown:SetPoint("RIGHT", resetBtn, "LEFT", -4, 0)

    local onlyGoldCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    onlyGoldCheck:SetSize(22, 22)
    onlyGoldCheck:SetPoint("TOPLEFT", 12, -10)

    local onlyGoldLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    onlyGoldLabel:SetPoint("LEFT", onlyGoldCheck, "RIGHT", 2, 0)
    onlyGoldLabel:SetText("Only show gold (hide silver/copper)")

    onlyGoldCheck:SetScript("OnClick", function(self)
        BT.db.settings.SetLedgerTabOnlyGold = self:GetChecked() and true or false
        panel.Refresh()
    end)

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 16, -46)
    header:SetPoint("TOPRIGHT", -16, -46)
    header:SetHeight(ROW_HEIGHT)

    local hSource = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hSource:SetPoint("LEFT", 4, 0)
    hSource:SetText("Source")
    hSource:SetTextColor(1, 0.82, 0)

    local hIncoming = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hIncoming:SetPoint("LEFT", header, "LEFT", 260, 0)
    hIncoming:SetText("Incoming")
    hIncoming:SetTextColor(1, 0.82, 0)

    local hOutgoing = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hOutgoing:SetPoint("LEFT", header, "LEFT", 460, 0)
    hOutgoing:SetText("Outgoing")
    hOutgoing:SetTextColor(1, 0.82, 0)

    local hNet = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hNet:SetPoint("LEFT", header, "LEFT", 600, 0)
    hNet:SetText("Net")
    hNet:SetTextColor(1, 0.82, 0)

    local rows = {}
    local rowsContainer = CreateFrame("Frame", nil, panel)
    rowsContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    rowsContainer:SetPoint("RIGHT", panel, "RIGHT", -16, 0)

    for i, catKey in ipairs(BT.CATEGORY_ORDER) do
        local row = CreateFrame("Frame", nil, rowsContainer)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", rowsContainer, "RIGHT", 0, 0)

        if i % 2 == 0 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(1, 1, 1, 0.03)
        end

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameFS:SetPoint("LEFT", 4, 0)
        nameFS:SetText(BT.CATEGORY_LABEL[catKey])
        nameFS:SetWidth(240)
        nameFS:SetJustifyH("LEFT")

        local inFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        inFS:SetPoint("LEFT", row, "LEFT", 260, 0)
        inFS:SetJustifyH("LEFT")

        local outFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        outFS:SetPoint("LEFT", row, "LEFT", 460, 0)
        outFS:SetJustifyH("LEFT")

        local netFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        netFS:SetPoint("LEFT", row, "LEFT", 600, 0)
        netFS:SetJustifyH("LEFT")

        rows[catKey] = { frame = row, incoming = inFS, outgoing = outFS, net = netFS }
    end
    rowsContainer:SetHeight(#BT.CATEGORY_ORDER * ROW_HEIGHT)

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.15)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", rowsContainer, "BOTTOMLEFT", 4, -4)
    sep:SetPoint("TOPRIGHT", rowsContainer, "BOTTOMRIGHT", -4, -4)

    local totalRow = CreateFrame("Frame", nil, panel)
    totalRow:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", -4, -6)
    totalRow:SetHeight(ROW_HEIGHT)

    local totalName = totalRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalName:SetPoint("LEFT", 4, 0)
    totalName:SetText("Net Total")

    local totalIn = totalRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalIn:SetPoint("LEFT", totalRow, "LEFT", 260, 0)

    local totalOut = totalRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalOut:SetPoint("LEFT", totalRow, "LEFT", 460, 0)

    local totalNet = totalRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    totalNet:SetPoint("LEFT", totalRow, "LEFT", 600, 0)

    local function Refresh()
        onlyGoldCheck:SetChecked(BT.db.settings.SetLedgerTabOnlyGold and true or false)
        local goldOnly = BT.db.settings.SetLedgerTabOnlyGold

        local days = BT.db.settings.graphRangeDays or 7
        local sums = {}
        for _, catKey in ipairs(BT.CATEGORY_ORDER) do
            sums[catKey] = { incoming = 0, outgoing = 0 }
        end

        local now = time()
        for i = 0, days - 1 do
            local key = BT:DayKey(now - i * 86400)
            local day = BT.db.ledger[key]
            if day then
                for catKey, entry in pairs(day) do
                    if sums[catKey] then
                        sums[catKey].incoming = sums[catKey].incoming + (entry.incoming or 0)
                        sums[catKey].outgoing = sums[catKey].outgoing + (entry.outgoing or 0)
                    end
                end
            end
        end

        local totalIncoming, totalOutgoing = 0, 0
        for _, catKey in ipairs(BT.CATEGORY_ORDER) do
            local s = sums[catKey]
            local row = rows[catKey]
            row.incoming:SetText(s.incoming > 0 and GUI.FormatMoney(s.incoming, goldOnly) or "-")
            row.outgoing:SetText(s.outgoing > 0 and GUI.FormatMoney(s.outgoing, goldOnly) or "-")
            row.net:SetText(GUI.FormatMoney(s.incoming - s.outgoing, goldOnly))
            totalIncoming = totalIncoming + s.incoming
            totalOutgoing = totalOutgoing + s.outgoing
        end
        totalIn:SetText(GUI.FormatMoney(totalIncoming, goldOnly))
        totalOut:SetText(GUI.FormatMoney(totalOutgoing, goldOnly))
        totalNet:SetText(GUI.FormatMoney(totalIncoming - totalOutgoing, goldOnly))
    end
    panel.Refresh = Refresh

    panel:SetScript("OnShow", Refresh)
    return panel
end
