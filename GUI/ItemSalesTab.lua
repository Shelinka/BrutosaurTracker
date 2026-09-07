local ADDON_NAME, BT = ...
local GUI = BT.GUI

local SORT_COLUMNS = {
    { key = "name", label = "Item", defaultDir = 1 },
    { key = "qty", label = "Qty Sold", defaultDir = -1 },
    { key = "totalCopper", label = "Total Gold", defaultDir = -1 },
    { key = "avg", label = "Avg Price", defaultDir = -1 },
}

local ROW_HEIGHT = 36
local VISIBLE_ROWS = 9

local function BuildHeaderText(label, columnKey, sortState)
    if sortState.key == columnKey then
        return label .. (sortState.dir == 1 and "  |cffffd700^|r" or "  |cffffd700v|r")
    end
    return label
end

function GUI.CreateItemSalesTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local dropdown

    local searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    searchBox:SetSize(180, 22)
    searchBox:SetPoint("TOPLEFT", 24, -12)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)

    local searchHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    searchHint:SetText("Search by item name")

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -8, -12)
    header:SetPoint("TOPRIGHT", -34, -46)
    header:SetHeight(18)

    local sortState = { key = "totalCopper", dir = -1 }
    local headerButtons = {}

    local COLUMN_X = { name = 40, qty = 300, totalCopper = 400, avg = 560 }

    local scrollFrame = CreateFrame("ScrollFrame", "BrutosaurTrackerSalesScroll", panel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)

    local emptyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyLabel:SetPoint("TOP", scrollFrame, "TOP", 0, -20)
    emptyLabel:SetText("No sales recorded yet for this range/search.")
    emptyLabel:Hide()

    local rows = {}
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", scrollFrame, "RIGHT", 0, 0)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", 4, 0)

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        name:SetWidth(250)
        name:SetJustifyH("LEFT")

        local qty = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        qty:SetPoint("LEFT", row, "LEFT", COLUMN_X.qty, 0)

        local total = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        total:SetPoint("LEFT", row, "LEFT", COLUMN_X.totalCopper, 0)

        local avg = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        avg:SetPoint("LEFT", row, "LEFT", COLUMN_X.avg, 0)

        rows[i] = { frame = row, icon = icon, name = name, qty = qty, total = total, avg = avg }
    end

    local fullList = {}    -- everything for the selected range
    local currentList = {} -- after search filter + sort

    local function ApplySearchAndSort()
        local query = searchBox:GetText():lower()
        wipe(currentList)
        for _, entry in ipairs(fullList) do
            if query == "" or (entry.name and entry.name:lower():find(query, 1, true)) then
                table.insert(currentList, entry)
            end
        end

        table.sort(currentList, function(a, b)
            local av, bv
            if sortState.key == "name" then
                av, bv = (a.name or ""):lower(), (b.name or ""):lower()
            elseif sortState.key == "avg" then
                av = a.qty > 0 and (a.totalCopper / a.qty) or 0
                bv = b.qty > 0 and (b.totalCopper / b.qty) or 0
            else
                av, bv = a[sortState.key] or 0, b[sortState.key] or 0
            end
            if sortState.dir == 1 then
                return av < bv
            end
            return av > bv
        end)

        for _, col in ipairs(SORT_COLUMNS) do
            headerButtons[col.key]:SetText(BuildHeaderText(col.label, col.key, sortState))
        end

        emptyLabel:SetShown(#currentList == 0)
        FauxScrollFrame_Update(scrollFrame, #currentList, VISIBLE_ROWS, ROW_HEIGHT)
    end

    local function UpdateRows()
        local offset = FauxScrollFrame_GetOffset(scrollFrame)
        for i = 1, VISIBLE_ROWS do
            local dataIndex = i + offset
            local entry = currentList[dataIndex]
            local row = rows[i]
            if entry then
                row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:SetText(entry.name or "Unknown Item")
                row.qty:SetText(tostring(entry.qty))
                row.total:SetText(GUI.FormatMoney(entry.totalCopper))
                local avgPrice = entry.qty > 0 and (entry.totalCopper / entry.qty) or 0
                row.avg:SetText(GUI.FormatMoney(avgPrice))
                row.frame:Show()
            else
                row.frame:Hide()
            end
        end
    end

    local function RefreshRows()
        ApplySearchAndSort()
        UpdateRows()
    end

    local function Refresh()
        local days = BT.db.settings.graphRangeDays or 7
        fullList = BT:GetItemSalesSummary(days)
        RefreshRows()
    end
    panel.Refresh = Refresh

    local prevHeader
    for _, col in ipairs(SORT_COLUMNS) do
        local btn = CreateFrame("Button", nil, header)
        btn:SetHeight(18)
        btn:SetWidth(col.key == "name" and 250 or 100)
        btn:SetPoint("LEFT", header, "LEFT", COLUMN_X[col.key], 0)

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", 0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetTextColor(1, 0.82, 0)
        btn.text = fs
        btn.SetText = function(_, text) fs:SetText(text) end

        btn:SetScript("OnClick", function()
            if sortState.key == col.key then
                sortState.dir = -sortState.dir
            else
                sortState.key = col.key
                sortState.dir = col.defaultDir
            end
            RefreshRows()
        end)

        headerButtons[col.key] = btn
    end

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateRows)
    end)

    searchBox:SetScript("OnTextChanged", function()
        RefreshRows()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    dropdown = GUI.CreateSharedRangeDropdown(panel, Refresh)
    dropdown:SetPoint("TOPRIGHT", -4, -8)

    panel:SetScript("OnShow", Refresh)
    return panel
end
