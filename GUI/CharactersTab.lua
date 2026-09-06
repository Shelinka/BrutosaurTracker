local ADDON_NAME, BT = ...
local GUI = BT.GUI

local ROW_HEIGHT = 28
local VISIBLE_ROWS = 11

StaticPopupDialogs["BRUTOSAURTRACKER_DELETE_CHAR"] = {
    text = "Remove %s from Brutosaur Tracker?\nThis only deletes its stored gold data from this list - it does not affect the character itself, and it will be tracked again if you log into it.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if data and data.guid then
            BT:DeleteCharacter(data.guid)
        end
        if data and data.onDone then data.onDone() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function GUI.CreateCharactersTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText("Tracked Characters")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetText("Remove a character if it was renamed, transferred, or deleted and you don't want its gold counted anymore.")

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 4, -16)
    header:SetPoint("TOPRIGHT", -34, 0)
    header:SetHeight(18)

    local hName = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hName:SetPoint("LEFT", 0, 0)
    hName:SetText("Character")
    hName:SetTextColor(1, 0.82, 0)

    local hGold = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hGold:SetPoint("LEFT", header, "LEFT", 320, 0)
    hGold:SetText("Gold")
    hGold:SetTextColor(1, 0.82, 0)

    local scrollFrame = CreateFrame("ScrollFrame", "BrutosaurTrackerCharsScroll", panel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)

    local rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", scrollFrame, "RIGHT", 0, 0)

        if i % 2 == 0 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            stripe:SetColorTexture(1, 1, 1, 0.03)
        end

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", 4, 0)
        name:SetWidth(300)
        name:SetJustifyH("LEFT")

        local gold = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        gold:SetPoint("LEFT", row, "LEFT", 320, 0)

        local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        delBtn:SetSize(70, 20)
        delBtn:SetText("Delete")
        delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

        rows[i] = { frame = row, name = name, gold = gold, delBtn = delBtn }
    end

    local emptyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyLabel:SetPoint("TOP", scrollFrame, "TOP", 0, -20)
    emptyLabel:SetText("No characters tracked yet.")
    emptyLabel:Hide()

    local currentList = {}
    local UpdateRows, Refresh -- forward-declared: each calls the other

    UpdateRows = function()
        local offset = FauxScrollFrame_GetOffset(scrollFrame)
        for i = 1, VISIBLE_ROWS do
            local entry = currentList[i + offset]
            local row = rows[i]
            if entry then
                row.name:SetText(entry.label .. (entry.isCurrent and "  |cff888888(this character)|r" or ""))
                row.gold:SetText(GUI.FormatMoney(entry.gold))
                row.delBtn:SetScript("OnClick", function()
                    StaticPopup_Show("BRUTOSAURTRACKER_DELETE_CHAR", entry.label, nil, { guid = entry.key, onDone = Refresh })
                end)
                -- stops user from deleting the character they are currently logged into, not sure why anyone would even want that but eh ¯\_(ツ)_/¯
                row.delBtn:SetShown(not entry.isCurrent)
                row.frame:Show()
            else
                row.frame:Hide()
            end
        end
    end

    Refresh = function()
        currentList = BT:GetCharacterBreakdown()
        emptyLabel:SetShown(#currentList == 0)
        FauxScrollFrame_Update(scrollFrame, #currentList, VISIBLE_ROWS, ROW_HEIGHT)
        UpdateRows()
    end
    panel.Refresh = Refresh

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateRows)
    end)

    panel:SetScript("OnShow", Refresh)
    return panel
end
