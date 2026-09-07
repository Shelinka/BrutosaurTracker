local ADDON_NAME, BT = ...

BT.ItemSales = {}
local IS = BT.ItemSales

function BT:RecordItemSale(name, icon, quantity, totalCopper)
    local dayKey = self:DayKey()
    local sales = self.db.itemSales
    sales[dayKey] = sales[dayKey] or {}
    local entry = sales[dayKey][name]
    if not entry then
        entry = { name = name, icon = icon, qty = 0, totalCopper = 0 }
        sales[dayKey][name] = entry
    end
    entry.qty = entry.qty + quantity
    entry.totalCopper = entry.totalCopper + totalCopper
    if icon then entry.icon = icon end
end


local pendingBackfill = {}

local function BackfillMissingIcons(name, icon)
    if not icon then return end
    for _, day in pairs(BT.db.itemSales) do
        local entry = day[name]
        if entry and not entry.icon then
            entry.icon = icon
        end
    end
end

function BT:RememberItemIcon(itemID)
    if not itemID then return end
    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if name and icon then
        local cached = self.db.itemIconCache[name]
        if not cached or cached.icon ~= icon then
            self.db.itemIconCache[name] = { id = itemID, icon = icon }
            BackfillMissingIcons(name, icon)
        end
    else
        pendingBackfill[itemID] = true
    end
end

local function ScanBagsForIcons()
    for bag = 0, 5 do
        local numSlots = C_Container and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                BT:RememberItemIcon(itemID)
            end
        end
    end
end


local function ResolveIcon(itemName)
    local cached = BT.db.itemIconCache[itemName]
    if cached then return cached.icon end

    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemName)
    return icon
end

local function HandleSellerInvoice(mailIndex)
    local invoiceType, itemName, playerName, bid, buyout, deposit, consignment,
        moneyDelay, etaHour, etaMin, count = GetInboxInvoiceInfo(mailIndex)

    if invoiceType ~= "seller" then return end
    if not itemName or not bid or bid <= 0 then return end

    local quantity = (count and count > 0) and count or 1
    BT:RecordItemSale(itemName, ResolveIcon(itemName), quantity, bid)
end


if TakeInboxMoney then
    local original = TakeInboxMoney
    TakeInboxMoney = function(index)
        pcall(HandleSellerInvoice, index)
        return original(index)
    end
end

if AutoLootMailItem then
    local original = AutoLootMailItem
    AutoLootMailItem = function(index)
        pcall(HandleSellerInvoice, index)
        return original(index)
    end
end


local iconFrame = CreateFrame("Frame")
IS.iconFrame = iconFrame

local function TryRegister(evt)
    pcall(iconFrame.RegisterEvent, iconFrame, evt)
end

TryRegister("PLAYER_LOGIN")
TryRegister("BAG_UPDATE_DELAYED")
TryRegister("GET_ITEM_INFO_RECEIVED")

iconFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "BAG_UPDATE_DELAYED" then
        ScanBagsForIcons()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID, success = ...
        if success and pendingBackfill[itemID] then
            pendingBackfill[itemID] = nil
            BT:RememberItemIcon(itemID)
        end
    end
end)

local function ItemIDFromItemLocation(itemLocation)
    if not itemLocation then return nil end
    if C_Item and C_Item.GetItemID then
        return C_Item.GetItemID(itemLocation)
    end
    return nil
end

if C_AuctionHouse and C_AuctionHouse.PostItem then
    hooksecurefunc(C_AuctionHouse, "PostItem", function(itemLocation)
        BT:RememberItemIcon(ItemIDFromItemLocation(itemLocation))
    end)
end
if C_AuctionHouse and C_AuctionHouse.PostCommodity then
    hooksecurefunc(C_AuctionHouse, "PostCommodity", function(itemLocation)
        BT:RememberItemIcon(ItemIDFromItemLocation(itemLocation))
    end)
end


function BT:GetItemSalesSummary(days)
    local totals = {}
    local now = time()
    for i = 0, days - 1 do
        local key = self:DayKey(now - i * 86400)
        local day = self.db.itemSales[key]
        if day then
            for name, entry in pairs(day) do
                local t = totals[name]
                if not t then
                    t = { name = name, icon = entry.icon, qty = 0, totalCopper = 0 }
                    totals[name] = t
                end
                t.qty = t.qty + entry.qty
                t.totalCopper = t.totalCopper + entry.totalCopper
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
