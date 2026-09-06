local ADDON_NAME, BT = ...

BT.GUI = BT.GUI or {}
local GUI = BT.GUI

----------------------------------------------------------------------
-- Money formatting
----------------------------------------------------------------------

-- Compact "1,234g 56s 78c" style string with coin colors baked in via |c.
function GUI.FormatMoney(copper)
    copper = math.floor(copper or 0)
    local negative = copper < 0
    copper = math.abs(copper)

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100

    local goldStr = string.format("|cffffd700%s|r", BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold))
    local str = string.format("%sg |cffc7c7cf%ds|r |cffb87333%dc|r", goldStr, silver, bronze)
    if negative then str = "-" .. str end
    return str
end

function GUI.FormatMoneyShort(copper)
    local gold = math.floor(math.abs(copper or 0) / 10000)
    local sign = (copper or 0) < 0 and "-" or ""
    if gold >= 1000000 then
        return string.format("%s%.1fM", sign, gold / 1000000)
    elseif gold >= 1000 then
        return string.format("%s%.1fk", sign, gold / 1000)
    end
    return string.format("%s%d", sign, gold)
end

-- Tab buttons


function GUI.CreateTabButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(110, 24)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- i don't wanna use libs so.. this will have to do ?

local PAD_LEFT = 58   -- for gold-amount labels
local PAD_RIGHT = 12
local PAD_TOP = 12
local PAD_BOTTOM = 22 -- for date labels
local NUM_Y_TICKS = 5
local NUM_X_TICKS = 6

local function GetOrCreateLine(pool, container)
    local line = table.remove(pool)
    if not line then
        line = container:CreateLine(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
    end
    return line
end

local function GetOrCreateLabel(pool, container)
    local fs = table.remove(pool)
    if not fs then
        fs = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    end
    return fs
end

function GUI.NewGraph(parent, width, height)
    local area = CreateFrame("Frame", nil, parent)
    area:SetSize(width, height)

    local graph = {
        area = area,
        linePool = {}, activeLines = {},
        labelPool = {}, activeLabels = {},
    }

    function graph:Clear()
        for _, line in ipairs(self.activeLines) do
            line:Hide()
            table.insert(self.linePool, line)
        end
        wipe(self.activeLines)
        for _, label in ipairs(self.activeLabels) do
            label:Hide()
            table.insert(self.labelPool, label)
        end
        wipe(self.activeLabels)
    end

    local function AddLine(self, x1, y1, x2, y2, thickness, r, g, b, a)
        local line = GetOrCreateLine(self.linePool, self.area)
        line:ClearAllPoints()
        line:SetThickness(thickness)
        line:SetColorTexture(r, g, b, a or 1)
        line:SetStartPoint("BOTTOMLEFT", self.area, x1, y1)
        line:SetEndPoint("BOTTOMLEFT", self.area, x2, y2)
        line:Show()
        table.insert(self.activeLines, line)
        return line
    end

    local function AddLabel(self, x, y, point, text)
        local label = GetOrCreateLabel(self.labelPool, self.area)
        label:ClearAllPoints()
        label:SetPoint(point, self.area, "BOTTOMLEFT", x, y)
        label:SetText(text)
        label:Show()
        table.insert(self.activeLabels, label)
        return label
    end

    function graph:SetData(points, goalY)
        self:Clear()
        if #points < 2 then return end

        local w, h = self.area:GetWidth(), self.area:GetHeight()
        if w <= 0 or h <= 0 then return end

        local minX, maxX = points[1].x, points[#points].x
        local minY, maxY = math.huge, -math.huge
        for _, p in ipairs(points) do
            if p.y < minY then minY = p.y end
            if p.y > maxY then maxY = p.y end
        end
        if goalY then
            minY = math.min(minY, goalY)
            maxY = math.max(maxY, goalY)
        end

        local yRange = maxY - minY
        if yRange <= 0 then yRange = math.max(10000, maxY * 0.1) end
        minY = math.max(0, minY - yRange * 0.1)
        maxY = maxY + yRange * 0.1
        if maxX == minX then maxX = minX + 86400 end

        local plotW = w - PAD_LEFT - PAD_RIGHT
        local plotH = h - PAD_TOP - PAD_BOTTOM

        local function toScreen(px, py)
            local sx = PAD_LEFT + (px - minX) / (maxX - minX) * plotW
            local sy = PAD_BOTTOM + (py - minY) / (maxY - minY) * plotH
            return sx, sy
        end

        for i = 0, NUM_Y_TICKS do
            local val = minY + (maxY - minY) * (i / NUM_Y_TICKS)
            local _, sy = toScreen(minX, val)
            AddLine(self, PAD_LEFT, sy, w - PAD_RIGHT, sy, 1, 1, 1, 1, i == 0 and 0.25 or 0.08)
            AddLabel(self, PAD_LEFT - 6, sy - 6, "BOTTOMRIGHT", GUI.FormatMoneyShort(val) .. "g")
        end

        local spanSeconds = maxX - minX
        local dateFormat
        if spanSeconds > 200 * 86400 then
            dateFormat = "%b %Y"
        elseif spanSeconds > 20 * 86400 then
            dateFormat = "%b %d"
        else
            dateFormat = "%m/%d"
        end
        for i = 0, NUM_X_TICKS do
            local tX = minX + spanSeconds * (i / NUM_X_TICKS)
            local sx = toScreen(tX, minY)
            AddLabel(self, sx, PAD_BOTTOM - 18, "BOTTOM", date(dateFormat, tX))
        end

        if goalY then
            local _, gy = toScreen(minX, goalY)
            AddLine(self, PAD_LEFT, gy, w - PAD_RIGHT, gy, 1.5, 1, 0.82, 0, 0.8)
        end

        local prevSx, prevSy
        for _, p in ipairs(points) do
            local sx, sy = toScreen(p.x, p.y)
            if prevSx then
                AddLine(self, prevSx, prevSy, sx, sy, 2.5, 0.2, 0.85, 0.3, 1)
            end
            prevSx, prevSy = sx, sy
        end
    end

    return graph
end
