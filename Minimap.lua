local ADDON_NAME, BT = ...

local button

local minimapShapes = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function UpdatePosition()
    local angle = math.rad(BT.db.settings.minimap.minimapPos or 220)
    local x, y = math.cos(angle), math.sin(angle)

    local quadrant = 1
    if x < 0 then quadrant = quadrant + 1 end
    if y > 0 then quadrant = quadrant + 2 end

    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local isRoundInThisQuadrant = minimapShapes[shape] and minimapShapes[shape][quadrant]

    local w = (Minimap:GetWidth() / 2) + 6
    local h = (Minimap:GetHeight() / 2) + 6

    if isRoundInThisQuadrant then
        x, y = x * w, y * h
    else
        local diagW, diagH = w * 1.41421356, h * 1.41421356
        x = math.max(-w, math.min(x * diagW, w))
        y = math.max(-h, math.min(y * diagH, h))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnUpdate(self)
    if not self.dragging then return end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    BT.db.settings.minimap.minimapPos = angle
    UpdatePosition()
end

function BT:CreateMinimapButton()
    if button then return button end

    button = CreateFrame("Button", "BrutosaurTrackerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")


    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture(BT.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER", 0, 0)
    button.icon = icon

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(icon)

    button:SetScript("OnDragStart", function(self) self.dragging = true end)
    button:SetScript("OnDragStop", function(self) self.dragging = false end)
    button:SetScript("OnUpdate", OnUpdate)

    button:SetScript("OnClick", function(_, mouseButton)
        BT:ToggleMainFrame()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Brutosaur Tracker")
        GameTooltip:AddLine("|cffffffffLeft-click:|r Open window", 1, 1, 1)
        GameTooltip:AddLine("|cffffffffDrag:|r Move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Minimap:HookScript("OnSizeChanged", UpdatePosition)

    UpdatePosition()
    return button
end

function BT:RefreshMinimapButton()
    self:CreateMinimapButton()
    if self.db.settings.minimap.hide then
        button:Hide()
    else
        button:Show()
        UpdatePosition()
    end
end
