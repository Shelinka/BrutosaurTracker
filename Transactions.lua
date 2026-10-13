local ADDON_NAME, BT = ...

BT.ItemTransactions = BT.ItemTransactions or {}

local pendingVendorSales = {}
local previousMoney
local tradeSnapshot

local function GetItemDetails(itemRef, fallbackName)
    local itemID = tonumber(itemRef)
    local itemName = fallbackName
    if type(itemRef) == "string" then
        itemName = itemName or itemRef:match("%[(.-)%]")
    end
    if not itemID and itemRef then
        itemID = BT:QueryItemInfoInstant(itemRef)
    end
    if not itemID and itemName and BT.db and BT.db.itemIconCache[itemName] then
        itemID = BT.db.itemIconCache[itemName].id
    end
    if itemID and not itemName then
        itemName = BT:QueryItemInfo(itemID)
    end
    return itemID, itemName
end

function BT:RecordItemTransaction(transactionType, itemID, itemName, quantity, totalCopper, source, timestamp, character)
    if transactionType ~= "purchase" and transactionType ~= "sale" then return end

    itemID, itemName = GetItemDetails(itemID, itemName)
    quantity = tonumber(quantity)
    totalCopper = tonumber(totalCopper)
    if not itemID or not quantity or quantity <= 0 or not totalCopper or totalCopper < 0 then return end

    if not itemName then
        itemName = self:QueryItemInfo(itemID)
    end

    local characterName = character and character.name or UnitName("player")
    local realm = character and character.realm or (GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName())
    table.insert(self.db.itemTransactions, {
        timestamp = timestamp or time(),
        type = transactionType,
        source = source or "unknown",
        characterGUID = character and character.guid or UnitGUID("player"),
        characterName = characterName,
        realm = realm,
        itemID = itemID,
        itemName = itemName or ("Item " .. itemID),
        quantity = math.floor(quantity),
        totalCopper = math.floor(totalCopper),
    })
end

local function RecordMerchantPurchase(index, requestedQuantity)
    if not GetMerchantItemLink then return end
    local itemName, price, stackSize
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(index)
        if info then
            itemName, price, stackSize = info.name, info.price, info.stackCount
        end
    elseif GetMerchantItemInfo then
        itemName, _, price, stackSize = GetMerchantItemInfo(index)
    end
    local itemLink = GetMerchantItemLink(index)
    stackSize = math.max(1, tonumber(stackSize) or 1)
    if not price or price <= 0 then return end
    local quantity = math.max(1, tonumber(requestedQuantity) or stackSize)
    local itemID, resolvedName = GetItemDetails(itemLink, itemName)
    BT:RecordItemTransaction("purchase", itemID, resolvedName, quantity, price / stackSize * quantity, "vendor")
end

local function RecordMerchantBuyback(index)
    if not GetBuybackItemInfo or not GetBuybackItemLink then return end
    local itemName, _, price, quantity = GetBuybackItemInfo(index)
    local itemLink = GetBuybackItemLink(index)
    if not price or price <= 0 then return end
    local itemID, resolvedName = GetItemDetails(itemLink, itemName)
    BT:RecordItemTransaction("purchase", itemID, resolvedName, quantity, price, "vendor_buyback")
end

local function OnPlayerMoneyChanged()
    local money = GetMoney()
    if previousMoney == nil then
        previousMoney = money
        return
    end
    local delta = money - previousMoney
    previousMoney = money
    if delta <= 0 then return end

    local now = GetTime()
    for index = #pendingVendorSales, 1, -1 do
        local entry = pendingVendorSales[index]
        if now - entry.time > 5 then
            table.remove(pendingVendorSales, index)
        elseif entry.totalCopper == delta then
            BT:RecordItemTransaction("sale", entry.itemID, entry.itemName, entry.quantity, entry.totalCopper, "vendor")
            table.remove(pendingVendorSales, index)
            return
        end
    end
end

local function OnUseContainerItem(bag, slot)
    if not MerchantFrame or not MerchantFrame:IsShown() or not C_Container then return end
    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if not itemLink then return end
    local itemName, _, _, _, _, _, _, _, _, _, sellPrice = BT:QueryItemInfo(itemLink)
    local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
    local quantity = itemInfo and itemInfo.stackCount or 1
    local itemID, resolvedName = GetItemDetails(itemLink, itemName)
    if not itemID or not sellPrice or sellPrice <= 0 then return end
    pendingVendorSales[#pendingVendorSales + 1] = {
        itemID = itemID,
        itemName = resolvedName,
        quantity = quantity,
        totalCopper = sellPrice * quantity,
        time = GetTime(),
    }
end

local function ReadTradeItems(isPlayer)
    local items, itemID, itemName, quantity = {}, nil, nil, 0
    for slot = 1, 6 do
        local link
        local count
        if isPlayer then
            link = GetTradePlayerItemLink(slot)
            local _, _, itemCount = GetTradePlayerItemInfo(slot)
            count = itemCount
        else
            link = GetTradeTargetItemLink(slot)
            local _, _, itemCount = GetTradeTargetItemInfo(slot)
            count = itemCount
        end
        if link then
            local currentID, currentName = GetItemDetails(link)
            if not currentID then return nil end
            if itemID and itemID ~= currentID then return nil end
            itemID, itemName = currentID, currentName
            quantity = quantity + (tonumber(count) or 1)
        end
    end
    if itemID then
        items.itemID = itemID
        items.itemName = itemName
        items.quantity = quantity
    end
    return items
end

local function OnTradeAcceptUpdate(playerAccepted, targetAccepted)
    if playerAccepted ~= 1 and targetAccepted ~= 1 then
        tradeSnapshot = nil
        return
    end
    tradeSnapshot = {
        playerMoney = tonumber(GetPlayerTradeMoney()) or 0,
        targetMoney = tonumber(GetTargetTradeMoney()) or 0,
        playerItems = ReadTradeItems(true),
        targetItems = ReadTradeItems(false),
    }
end

local function OnTradeComplete(message)
    if message ~= LE_GAME_ERR_TRADE_COMPLETE or not tradeSnapshot then return end
    local transactionType, item, totalCopper
    if tradeSnapshot.playerMoney > 0 and tradeSnapshot.targetMoney == 0
        and tradeSnapshot.playerItems and not tradeSnapshot.playerItems.itemID
        and tradeSnapshot.targetItems and tradeSnapshot.targetItems.itemID then
        transactionType, item, totalCopper = "purchase", tradeSnapshot.targetItems, tradeSnapshot.playerMoney
    elseif tradeSnapshot.targetMoney > 0 and tradeSnapshot.targetItems and not tradeSnapshot.targetItems.itemID
        and tradeSnapshot.playerItems and tradeSnapshot.playerItems.itemID then
        transactionType, item, totalCopper = "sale", tradeSnapshot.playerItems, tradeSnapshot.targetMoney
    end
    if transactionType and item then
        BT:RecordItemTransaction(transactionType, item.itemID, item.itemName, item.quantity, totalCopper, "trade")
    end
    tradeSnapshot = nil
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("TRADE_ACCEPT_UPDATE")
eventFrame:RegisterEvent("UI_INFO_MESSAGE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        previousMoney = GetMoney()
    elseif event == "PLAYER_MONEY" then
        OnPlayerMoneyChanged()
    elseif event == "TRADE_ACCEPT_UPDATE" then
        OnTradeAcceptUpdate(...)
    elseif event == "UI_INFO_MESSAGE" then
        OnTradeComplete(...)
    end
end)

if BuyMerchantItem then
    hooksecurefunc("BuyMerchantItem", RecordMerchantPurchase)
end
if BuybackItem then
    hooksecurefunc("BuybackItem", RecordMerchantBuyback)
end
if C_Container and C_Container.UseContainerItem then
    hooksecurefunc(C_Container, "UseContainerItem", OnUseContainerItem)
end

if SendMail then
    local originalSendMail = SendMail
    SendMail = function(recipient, ...)
        local codAmount = GetSendMailCOD and GetSendMailCOD() or 0
        if codAmount > 0 then
            local pending
            for attachment = 1, 12 do
                local itemName, _, _, quantity = GetSendMailItem(attachment)
                if itemName and quantity and quantity > 0 then
                    local itemLink = GetSendMailItemLink and GetSendMailItemLink(attachment)
                    local itemID, resolvedName = GetItemDetails(itemLink or itemName, itemName)
                    if not itemID or (pending and pending.itemID ~= itemID) then
                        pending = nil
                        break
                    end
                    if not pending then
                        pending = { itemID = itemID, itemName = resolvedName, quantity = 0 }
                    end
                    pending.quantity = pending.quantity + quantity
                end
            end
            if pending then
                pending.recipient = recipient
                pending.totalCopper = codAmount
                pending.timestamp = time()
                pending.character = {
                    guid = UnitGUID("player"),
                    name = UnitName("player"),
                    realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName(),
                }
                table.insert(BT.db.pendingCODSales, pending)
            end
        end
        return originalSendMail(recipient, ...)
    end
end