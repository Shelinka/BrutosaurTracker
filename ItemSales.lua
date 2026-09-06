local ADDON_NAME, BT = ...

BT.ItemSales = {}
local IS = BT.ItemSales

IS.cancellingIDs = {}      -


function BT:RecordItemSale(itemID, name, icon, quantity, totalCopper)
    local dayKey = self:DayKey()
    local sales = self.db.itemSales
    sales[dayKey] = sales[dayKey] or {}
    local entry = sales[dayKey][itemID]
    if not entry then
        entry = { name = name, icon = icon, qty = 0, totalCopper = 0 }
        sales[dayKey][itemID] = entry
    end
    entry.qty = entry.qty + quantity
    entry.totalCopper = entry.totalCopper + totalCopper
    if name and name ~= "" then entry.name = name end
    if icon then entry.icon = icon end
end


local function BuildSnapshot()
    local snapshot = {}
    if not (C_AuctionHouse and C_AuctionHouse.GetOwnedAuctions) then
        return snapshot
    end
    local owned = C_AuctionHouse.GetOwnedAuctions()
    if not owned then return snapshot end

    for _, auction in ipairs(owned) do
        local itemID = auction.itemKey and auction.itemKey.itemID
        if itemID and auction.auctionID then
            snapshot[auction.auctionID] = {
                itemID = itemID,
                quantity = auction.quantity or 1,
                buyoutAmount = auction.buyoutAmount or 0,
            }
        end
    end
    return snapshot
end

local function ResolveItemDisplay(itemID)
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    return name, icon
end

function IS:CheckForSoldAuctions()
    local persisted = BT.db.auctionSnapshot
    local newSnapshot = BuildSnapshot()

    for auctionID, oldEntry in pairs(persisted) do
        if not newSnapshot[auctionID] then
            if not self.cancellingIDs[auctionID] then
                local name, icon = ResolveItemDisplay(oldEntry.itemID)
                BT:RecordItemSale(
                    oldEntry.itemID,
                    name or ("item:" .. oldEntry.itemID),
                    icon,
                    oldEntry.quantity,
                    oldEntry.buyoutAmount
                )
            end
            self.cancellingIDs[auctionID] = nil
        end
    end

    BT.db.auctionSnapshot = newSnapshot
end

function BT:GetItemSalesSummary(days)
    local totals = {} 
    local now = time()
    for i = 0, days - 1 do
        local key = self:DayKey(now - i * 86400)
        local day = self.db.itemSales[key]
        if day then
            for itemID, entry in pairs(day) do
                local t = totals[itemID]
                if not t then
                    t = { itemID = itemID, name = entry.name, icon = entry.icon, qty = 0, totalCopper = 0 }
                    totals[itemID] = t
                end
                t.qty = t.qty + entry.qty
                t.totalCopper = t.totalCopper + entry.totalCopper
                if entry.name and entry.name ~= "" then t.name = entry.name end
                if entry.icon then t.icon = entry.icon end
            end
        end
    end

    local list = {}
    for _, t in pairs(totals) do
        table.insert(list, t)
    end
    table.sort(list, function(a, b) return a.totalCopper > b.totalCopper end)
    return list
end


local f = CreateFrame("Frame")
IS.frame = f

local function TryRegister(evt)
    pcall(f.RegisterEvent, f, evt)
end

TryRegister("OWNED_AUCTIONS_UPDATED")
TryRegister("AUCTION_HOUSE_SHOW")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then
            pcall(C_AuctionHouse.QueryOwnedAuctions, { sorts = {} })
        end
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        IS:CheckForSoldAuctions()
    end
end)

if C_AuctionHouse and C_AuctionHouse.CancelAuction then
    hooksecurefunc(C_AuctionHouse, "CancelAuction", function(auctionID)
        if auctionID then
            IS.cancellingIDs[auctionID] = true
        end
    end)
end
