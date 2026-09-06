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


local function ResolveIcon(itemName)
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

-- Wrapping (not hooksecurefunc) so the invoice can be read BEFORE the
-- original call runs and potentially removes/changes the mail at that index.
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
