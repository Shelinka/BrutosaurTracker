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
    local name, _, _, _, _, _, _, _, _, icon = self:QueryItemInfo(itemID)
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

    local _, _, _, _, _, _, _, _, _, icon = BT:QueryItemInfo(itemName)
    return icon
end

local processedMailTransactions = {}

local function GetMailTransactionTime(daysLeft, maxDays)
    return time() + ((tonumber(daysLeft) or maxDays) - maxDays) * 86400
end

local function HandleAuctionInvoice(mailIndex, action)
    local invoiceType, itemName, playerName, bid, buyout, deposit, consignment,
        moneyDelay, etaHour, etaMin, count = GetInboxInvoiceInfo(mailIndex)

    local transactionType
    if invoiceType == "seller" and (action == "money" or action == "auto") then
        transactionType = "sale"
    elseif invoiceType == "buyer" and (action == "item" or action == "auto") then
        transactionType = "purchase"
    else
        return
    end
    if not itemName or not bid or bid <= 0 then return end

    local quantity = (count and count > 0) and count or 1
    local signature = table.concat({ mailIndex, invoiceType, itemName, bid, quantity }, "|")
    if processedMailTransactions[signature] then return end
    processedMailTransactions[signature] = true

    local itemID = BT:QueryItemInfoInstant(itemName)
    local _, _, _, _, _, _, daysLeft = GetInboxHeaderInfo(mailIndex)
    if BT.RecordItemTransaction then
        BT:RecordItemTransaction(transactionType, itemID, itemName, quantity, bid, "auction_house",
            GetMailTransactionTime(daysLeft, 30))
    end
    if transactionType == "sale" then
        BT:RecordItemSale(itemName, ResolveIcon(itemName), quantity, bid)
    end
end

local function HandleCODMail(mailIndex, action)
    if action == "money" then return end
    local _, _, _, _, _, codAmount, daysLeft = GetInboxHeaderInfo(mailIndex)
    if not codAmount or codAmount <= 0 then return end

    local itemID, itemName, quantity
    for attachment = 1, (ATTACHMENTS_MAX_RECEIVE or 12) do
        local name, _, count = GetInboxItem(mailIndex, attachment)
        if not name then break end
        local link = GetInboxItemLink and GetInboxItemLink(mailIndex, attachment)
        local currentID = BT:QueryItemInfoInstant(link or name)
        if not currentID or (itemID and itemID ~= currentID) then return end
        itemID = currentID
        itemName = itemName or name
        quantity = (quantity or 0) + (tonumber(count) or 0)
    end
    if not itemID or not quantity or quantity <= 0 then return end

    local signature = table.concat({ mailIndex, "cod", itemID, codAmount, quantity }, "|")
    if processedMailTransactions[signature] then return end
    processedMailTransactions[signature] = true
    if BT.RecordItemTransaction then
        BT:RecordItemTransaction("purchase", itemID, itemName, quantity, codAmount, "cod_mail",
            GetMailTransactionTime(daysLeft, 3))
    end
end

local function NormalizeMailName(name)
    if not name then return "" end
    if Ambiguate then
        name = Ambiguate(name, "none")
    end
    return name:lower()
end

local function HandleCODSalePayment(mailIndex, action)
    if action ~= "money" then return end
    local _, _, sender, _, money = GetInboxHeaderInfo(mailIndex)
    if not sender or not money or money <= 0 then return end

    local normalizedSender = NormalizeMailName(sender)
    for index, pending in ipairs(BT.db.pendingCODSales) do
        if NormalizeMailName(pending.recipient) == normalizedSender and pending.totalCopper == money then
            if BT.RecordItemTransaction then
                BT:RecordItemTransaction("sale", pending.itemID, pending.itemName, pending.quantity,
                    pending.totalCopper, "cod_mail", time(), pending.character)
            end
            table.remove(BT.db.pendingCODSales, index)
            return
        end
    end
end

local function WrapMailAction(functionName, action)
    local original = _G[functionName]
    if not original then return end
    _G[functionName] = function(mailIndex, ...)
        pcall(HandleAuctionInvoice, mailIndex, action)
        pcall(HandleCODMail, mailIndex, action)
        pcall(HandleCODSalePayment, mailIndex, action)
        return original(mailIndex, ...)
    end
end

WrapMailAction("TakeInboxMoney", "money")
WrapMailAction("TakeInboxItem", "item")
WrapMailAction("AutoLootMailItem", "auto")


local iconFrame = CreateFrame("Frame")
IS.iconFrame = iconFrame

local function TryRegister(evt)
    pcall(iconFrame.RegisterEvent, iconFrame, evt)
end

TryRegister("PLAYER_LOGIN")
TryRegister("BAG_UPDATE_DELAYED")
TryRegister("GET_ITEM_INFO_RECEIVED")
TryRegister("MAIL_INBOX_UPDATE")

iconFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "BAG_UPDATE_DELAYED" then
        ScanBagsForIcons()
    elseif event == "MAIL_INBOX_UPDATE" then
        wipe(processedMailTransactions)
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
