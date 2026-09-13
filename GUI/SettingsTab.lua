local ADDON_NAME, BT = ...
local GUI = BT.GUI

local function RGBToHex(r, g, b)
    return string.format("%02X%02X%02X",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function HexToRGB(hex)
    hex = hex:gsub("^#", ""):gsub("^0[xX]", "")
    if #hex ~= 6 or hex:match("%X") then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return r / 255, g / 255, b / 255
end

function GUI.CreateSettingsTab(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Settings")


    local goalHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goalHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    goalHeader:SetText("Gold Goal")
    goalHeader:SetTextColor(1, 0.82, 0)

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", goalHeader, "BOTTOMLEFT", 0, -14)
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

    local progressBox = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
    progressBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -4, -24)
    progressBox:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    progressBox:SetHeight(110)

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


    local colorHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorHeader:SetPoint("TOPLEFT", progressBox, "BOTTOMLEFT", 4, -20)
    colorHeader:SetText("Graph Line Color")
    colorHeader:SetTextColor(1, 0.82, 0)

    local colorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", colorHeader, "BOTTOMLEFT", 0, -14)
    colorLabel:SetText("Hex:")

    local hexBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    hexBox:SetSize(80, 24)
    hexBox:SetPoint("LEFT", colorLabel, "RIGHT", 44, 0)
    hexBox:SetAutoFocus(false)
    hexBox:SetMaxLetters(7)

    local swatch = CreateFrame("Button", nil, panel)
    swatch:SetSize(24, 24)
    swatch:SetPoint("LEFT", hexBox, "RIGHT", 14, 0)

    local swatchBorder = swatch:CreateTexture(nil, "BACKGROUND")
    swatchBorder:SetPoint("TOPLEFT", -2, 2)
    swatchBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    swatchBorder:SetColorTexture(1, 1, 1, 0.5)

    local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
    swatchTex:SetAllPoints()

    local pickBtn = GUI.CreateTabButton(panel, "Pick Color...", nil)
    pickBtn:SetPoint("LEFT", swatch, "RIGHT", 14, 0)
    pickBtn:SetSize(120, 24)

    local classBtn = GUI.CreateTabButton(panel, "Use Class Color", nil)
    classBtn:SetPoint("LEFT", pickBtn, "RIGHT", 8, 0)
    classBtn:SetSize(130, 24)

    local colorError = panel:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    colorError:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -6)
    colorError:Hide()

    local function ApplyHexFromBox()
        local r, g, b = HexToRGB(hexBox:GetText())
        if not r then
            colorError:SetText("Enter a valid 6-digit hex code, e.g. 33D94D")
            colorError:Show()
            return
        end
        colorError:Hide()
        BT.db.settings.graphColorMode = "custom"
        BT.db.settings.graphColor = { r = r, g = g, b = b }
        panel.Refresh()
        if BT.mainFrame and BT.mainFrame.RefreshAll then BT.mainFrame.RefreshAll() end
        hexBox:ClearFocus()
    end
    hexBox:SetScript("OnEnterPressed", ApplyHexFromBox)

    pickBtn:SetScript("OnClick", function()
        local r, g, b = BT:GetGraphLineColor()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                BT.db.settings.graphColorMode = "custom"
                BT.db.settings.graphColor = { r = nr, g = ng, b = nb }
                colorError:Hide()
                panel.Refresh()
                if BT.mainFrame and BT.mainFrame.RefreshAll then BT.mainFrame.RefreshAll() end
            end,
            cancelFunc = function(previousValues)
                BT.db.settings.graphColorMode = "custom"
                BT.db.settings.graphColor = { r = previousValues.r, g = previousValues.g, b = previousValues.b }
                panel.Refresh()
                if BT.mainFrame and BT.mainFrame.RefreshAll then BT.mainFrame.RefreshAll() end
            end,
        })
    end)

    classBtn:SetScript("OnClick", function()
        if BT.db.settings.graphColorMode == "class" then
            BT.db.settings.graphColorMode = "custom"
        else
            BT.db.settings.graphColorMode = "class"
            colorError:Hide()
        end
        panel.Refresh()
        if BT.mainFrame and BT.mainFrame.RefreshAll then BT.mainFrame.RefreshAll() end
    end)

    ------------------------------------------------------------------

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

        local r, g, b = BT:GetGraphLineColor()
        swatchTex:SetColorTexture(r, g, b)

        if BT.db.settings.graphColorMode == "class" then
            local _, classFile = UnitClass("player")
            colorLabel:SetText("Class:")
            hexBox:SetText(classFile and classFile:sub(1, 1) .. classFile:sub(2):lower() or "?")
            hexBox:EnableMouse(false)
            hexBox:EnableKeyboard(false)
            hexBox:SetTextColor(0.6, 0.6, 0.6)
            classBtn:SetText("Use Custom Color")
        else
            colorLabel:SetText("Hex:")
            hexBox:EnableMouse(true)
            hexBox:EnableKeyboard(true)
            hexBox:SetTextColor(1, 1, 1)
            hexBox:SetText(RGBToHex(r, g, b))
            classBtn:SetText("Use Class Color")
        end
    end
    panel.Refresh = Refresh
    panel:SetScript("OnShow", Refresh)

    return panel
end
