local ADDON_NAME, BT = ...
local CAT = BT.CATEGORY

BT.MoneyTracker = {}
local MT = BT.MoneyTracker

MT.lastMoney = nil
MT.windowContext = nil
MT.oneShotContext = nil
MT.oneShotExpireTimer = nil
MT.suppressNext = nil
MT.suppressExpireTimer = nil

function BT:RecordLedgerEntry(category, deltaCopper)
    if deltaCopper == 0 then return end
    local dayKey = self:DayKey()
    local ledger = self.db.ledger
    ledger[dayKey] = ledger[dayKey] or {}
    local dayCat = ledger[dayKey][category]
    if not dayCat then
        dayCat = { incoming = 0, outgoing = 0 }
        ledger[dayKey][category] = dayCat
    end
    if deltaCopper > 0 then
        dayCat.incoming = dayCat.incoming + deltaCopper
    else
        dayCat.outgoing = dayCat.outgoing + (-deltaCopper)
    end
end

local windowGeneration = 0

local function SetWindowContext(cat)
    windowGeneration = windowGeneration + 1
    MT.windowContext = cat
end

local function ClearWindowContext(cat)
    local gen = windowGeneration
    C_Timer.After(2, function()
        if MT.windowContext == cat and windowGeneration == gen then
            MT.windowContext = nil
        end
    end)
end

local function SetOneShotContext(cat)
    MT.oneShotContext = cat
    if MT.oneShotExpireTimer then
        MT.oneShotExpireTimer:Cancel()
    end
    MT.oneShotExpireTimer = C_Timer.NewTimer(5, function()
        MT.oneShotContext = nil
        MT.oneShotExpireTimer = nil
    end)
end

local function SetSuppressNextDelta()
    MT.suppressNext = true
    if MT.suppressExpireTimer then
        MT.suppressExpireTimer:Cancel()
    end
    MT.suppressExpireTimer = C_Timer.NewTimer(5, function()
        MT.suppressNext = nil
        MT.suppressExpireTimer = nil
    end)
end

local function HandleMoneyChanged()
    local newMoney = GetMoney()
    if MT.lastMoney == nil then
        MT.lastMoney = newMoney
        return
    end
    local delta = newMoney - MT.lastMoney
    MT.lastMoney = newMoney
    if delta == 0 then return end

    if MT.suppressNext then
        MT.suppressNext = nil
        if MT.suppressExpireTimer then
            MT.suppressExpireTimer:Cancel()
            MT.suppressExpireTimer = nil
        end
        return
    end

    local category = MT.oneShotContext or MT.windowContext or CAT.OTHER
    BT:RecordLedgerEntry(category, delta)

    if MT.oneShotContext then
        MT.oneShotContext = nil
        if MT.oneShotExpireTimer then
            MT.oneShotExpireTimer:Cancel()
            MT.oneShotExpireTimer = nil
        end
    end
end

local f = CreateFrame("Frame")
MT.frame = f

local WATCHED_EVENTS = {
    "PLAYER_MONEY",
    "PLAYER_ENTERING_WORLD",

    "MERCHANT_SHOW", "MERCHANT_CLOSED",
    "TRADE_SHOW", "TRADE_CLOSED",
    "MAIL_SHOW", "MAIL_CLOSED",
    "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED",
    "TAXIMAP_OPENED", "TAXIMAP_CLOSED",

    "QUEST_TURNED_IN",
    "CHAT_MSG_MONEY",

    "ITEM_PURCHASED",
    "COMMODITY_PURCHASE_SUCCEEDED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",

    "BLACK_MARKET_WON",
}

for _, evt in ipairs(WATCHED_EVENTS) do
    local ok = pcall(f.RegisterEvent, f, evt)
    if not ok then
    end
end

local function PruneOldPendingBids()
    local cutoff = time() - 3 * 86400
    local pending = BT.db.blackMarketPendingBids
    for i = #pending, 1, -1 do
        if pending[i].t < cutoff then
            table.remove(pending, i)
        end
    end
end

local function RecordPendingBid(marketID, amount)
    table.insert(BT.db.blackMarketPendingBids, { marketID = marketID, amount = amount, t = time() })
    PruneOldPendingBids()
end

local function ConsumePendingBidByAmount(amount)
    local pending = BT.db.blackMarketPendingBids
    for i, entry in ipairs(pending) do
        if entry.amount == amount then
            table.remove(pending, i)
            return true
        end
    end
    return false
end

local function ConsumePendingBidByMarketID(marketID)
    local pending = BT.db.blackMarketPendingBids
    for i, entry in ipairs(pending) do
        if entry.marketID == marketID then
            table.remove(pending, i)
            return true
        end
    end
    return false
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        MT.lastMoney = GetMoney()

    elseif event == "PLAYER_MONEY" then
        HandleMoneyChanged()

    elseif event == "MERCHANT_SHOW" then
        SetWindowContext(CAT.MERCHANTS)
    elseif event == "MERCHANT_CLOSED" then
        ClearWindowContext(CAT.MERCHANTS)

    elseif event == "TRADE_SHOW" then
        SetWindowContext(CAT.TRADE)
    elseif event == "TRADE_CLOSED" then
        ClearWindowContext(CAT.TRADE)

    elseif event == "MAIL_SHOW" then
        SetWindowContext(CAT.MAIL)
    elseif event == "MAIL_CLOSED" then
        ClearWindowContext(CAT.MAIL)

    elseif event == "GUILDBANKFRAME_OPENED" then
        SetWindowContext(CAT.GUILD)
    elseif event == "GUILDBANKFRAME_CLOSED" then
        ClearWindowContext(CAT.GUILD)

    elseif event == "TAXIMAP_OPENED" then
        SetWindowContext(CAT.TAXI)
    elseif event == "TAXIMAP_CLOSED" then
        ClearWindowContext(CAT.TAXI)

    elseif event == "QUEST_TURNED_IN" then
        local questID, xpReward, moneyReward = ...
        if moneyReward and moneyReward ~= 0 then
            SetOneShotContext(CAT.QUESTS)
        end

    elseif event == "CHAT_MSG_MONEY" then
        SetOneShotContext(CAT.LOOT)

    elseif event == "ITEM_PURCHASED" or event == "COMMODITY_PURCHASE_SUCCEEDED" then
        SetOneShotContext(CAT.AUCTIONS)

    elseif event == "AUCTION_HOUSE_SHOW" then
        SetWindowContext(CAT.AUCTIONS)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ClearWindowContext(CAT.AUCTIONS)

    elseif event == "BLACK_MARKET_WON" then
        local marketID = ...
        if marketID then
            ConsumePendingBidByMarketID(marketID)
        end
    end
end)

if RepairAllItems then
    hooksecurefunc("RepairAllItems", function()
        SetOneShotContext(CAT.REPAIR)
    end)
end
if RepairItem then
    hooksecurefunc("RepairItem", function()
        SetOneShotContext(CAT.REPAIR)
    end)
end

if BuyTrainerService then
    hooksecurefunc("BuyTrainerService", function()
        SetOneShotContext(CAT.TRAINING)
    end)
end

if C_Transmog and C_Transmog.ApplyPending then
    hooksecurefunc(C_Transmog, "ApplyPending", function()
        SetOneShotContext(CAT.TRANSMOG)
    end)
end

if TakeTaxiNode then
    hooksecurefunc("TakeTaxiNode", function()
        SetOneShotContext(CAT.TAXI)
    end)
end


if C_AuctionHouse and C_AuctionHouse.PlaceBid then
    hooksecurefunc(C_AuctionHouse, "PlaceBid", function()
        SetOneShotContext(CAT.AUCTIONS)
    end)
end
if C_AuctionHouse and C_AuctionHouse.StartCommoditiesPurchase then
    hooksecurefunc(C_AuctionHouse, "StartCommoditiesPurchase", function()
        SetOneShotContext(CAT.AUCTIONS)
    end)
end

if C_BlackMarket and C_BlackMarket.ItemPlaceBid then
    hooksecurefunc(C_BlackMarket, "ItemPlaceBid", function(marketID, bid)
        SetOneShotContext(CAT.BLACKMARKET)
        if marketID and bid then
            RecordPendingBid(marketID, bid)
        end
    end)
end

if C_Bank and C_Bank.DepositMoney and Enum and Enum.BankType then
    hooksecurefunc(C_Bank, "DepositMoney", function(bankType)
        if bankType == Enum.BankType.Account then
            SetSuppressNextDelta()
        end
    end)
end
if C_Bank and C_Bank.WithdrawMoney and Enum and Enum.BankType then
    hooksecurefunc(C_Bank, "WithdrawMoney", function(bankType)
        if bankType == Enum.BankType.Account then
            SetSuppressNextDelta()
        end
    end)
end

local function IsAuctionHouseSender(sender)
    if not sender then return false end
    if AUCTION_HOUSE_MAILBOX_SENDER and sender == AUCTION_HOUSE_MAILBOX_SENDER then
        return true
    end
    return sender == "Auction House"
end

local function LooksLikeBlackMarketSender(sender)
    if not sender then return false end
    return sender:find("Black Market", 1, true) ~= nil
end

local function TagMailMoneyContext(mailIndex)
    local _, _, sender, subject, moneyAmount = GetInboxHeaderInfo(mailIndex)

    if IsAuctionHouseSender(sender) then
        SetOneShotContext(CAT.AUCTIONS)
        return
    end

    if LooksLikeBlackMarketSender(sender) then
        SetOneShotContext(CAT.BLACKMARKET)
        if moneyAmount then
            ConsumePendingBidByAmount(moneyAmount)
        end
        return
    end

    if moneyAmount and moneyAmount > 0 and ConsumePendingBidByAmount(moneyAmount) then
        SetOneShotContext(CAT.BLACKMARKET)
    end
end

if TakeInboxMoney then
    hooksecurefunc("TakeInboxMoney", function(mailIndex)
        TagMailMoneyContext(mailIndex)
    end)
end
if AutoLootMailItem then
    hooksecurefunc("AutoLootMailItem", function(mailIndex)
        TagMailMoneyContext(mailIndex)
    end)
end
