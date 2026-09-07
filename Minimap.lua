local ADDON_NAME, BT = ...

local button

local function UpdatePosition()
    local angle = math.rad(BT.db.settings.minimap.minimapPos or 220)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
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

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture(BT.ICON)
    icon:SetPoint("CENTER", 0, 1)

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
