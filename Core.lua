local ADDON_NAME, BT = ...
_G.BrutosaurTracker = BT

BT.ADDON_NAME = ADDON_NAME
BT.ICON = "Interface\\Icons\\inv_brontosaurusmount"
BT.VERSION = "1.0.0"

-- Category constants shared by MoneyTracker, ItemSales and the GUI.
BT.CATEGORY = {
    TAXI        = "TAXI",
    GUILD       = "GUILD",
    OTHER       = "OTHER",
    TRANSMOG    = "TRANSMOG",
    TRADE       = "TRADE",
    MAIL        = "MAIL",
    QUESTS      = "QUESTS",
    LOOT        = "LOOT",
    REPAIR      = "REPAIR",
    TRAINING    = "TRAINING",
    AUCTIONS    = "AUCTIONS",
    MERCHANTS   = "MERCHANTS",
}

BT.CATEGORY_ORDER = {
    "TAXI", "GUILD", "OTHER", "TRANSMOG", "TRADE", "MAIL",
    "QUESTS", "LOOT", "REPAIR", "TRAINING", "AUCTIONS", "MERCHANTS",
}

BT.CATEGORY_LABEL = {
    TAXI        = "Taxi Fares",
    GUILD       = "Guild",
    OTHER       = "Other",
    TRANSMOG    = "Transmogrify",
    TRADE       = "Trade Window",
    MAIL        = "Mail",
    QUESTS      = "Quests",
    LOOT        = "Loot",
    REPAIR      = "Repair Costs",
    TRAINING    = "Training Costs",
    AUCTIONS    = "Auctions",
    MERCHANTS   = "Merchants",
}


local function GetDefaults()
    return {
        version = 1,

        settings = {
            graphRangeDays = 365,
            goldGoal = 0,
            minimap = { hide = false, minimapPos = 220 },
        },

        characters = {},

        snapshots = {},

        ledger = {},

        itemSales = {},


        auctionSnapshot = {},
    }
end

local function EnsureTable(t, key, default)
    if t[key] == nil then t[key] = default end
    return t[key]
end

function BT:InitDB()
    if not BrutosaurTrackerDB then
        BrutosaurTrackerDB = GetDefaults()
    end
    local db = BrutosaurTrackerDB
    local defaults = GetDefaults()

    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v
        elseif type(v) == "table" then
            for k2, v2 in pairs(v) do
                if db[k][k2] == nil then db[k][k2] = v2 end
            end
        end
    end

    self.db = db
end

function BT:GetCharGUID()
    return UnitGUID("player")
end

function BT:GetCharDisplayName()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName() or GetRealmName()
    return name .. "-" .. realm
end

function BT:UpdateCharacterRecord()
    if not self.db then self:InitDB() end
    local guid = self:GetCharGUID()
    if not guid then return end

    local name = UnitName("player")
    local normalizedRealm = GetNormalizedRealmName()
    local rawRealm = GetRealmName()
    local displayName = name .. "-" .. (normalizedRealm or rawRealm)

    if not self.db.characters[guid] then
        local candidateKeys = {}
        if normalizedRealm and normalizedRealm ~= "" then
            table.insert(candidateKeys, name .. "-" .. normalizedRealm)
        end
        if rawRealm and rawRealm ~= "" and rawRealm ~= normalizedRealm then
            table.insert(candidateKeys, name .. "-" .. rawRealm)
        end

        local best
        for _, legacyKey in ipairs(candidateKeys) do
            local legacyRec = self.db.characters[legacyKey]
            if legacyRec and (not best or (legacyRec.lastSeen or 0) > (best.lastSeen or 0)) then
                best = legacyRec
            end
        end
        if best then
            self.db.characters[guid] = best
        end
        for _, legacyKey in ipairs(candidateKeys) do
            self.db.characters[legacyKey] = nil
        end
    end

    local _, classFile = UnitClass("player")
    local rec = EnsureTable(self.db.characters, guid, {})

    rec.gold = newGold
    rec.class = classFile
    rec.faction = UnitFactionGroup("player")
    rec.name = name
    rec.realm = normalizedRealm or rawRealm
    rec.displayName = displayName
    rec.lastSeen = time()
    self.db.characters[guid] = rec
end

function BT:DeleteCharacter(guid)
    self.db.characters[guid] = nil
end

function BT:GetCharacterBreakdown()
    local list = {}
    local currentGUID = self:GetCharGUID()
    for guid, rec in pairs(self.db.characters) do
        list[#list + 1] = {
            key = guid,
            label = rec.displayName or rec.name or guid,
            gold = rec.gold or 0,
            isCurrent = (guid == currentGUID),
        }
    end
    table.sort(list, function(a, b) return a.gold > b.gold end)
    return list
end


function BT:GetWarbandGold()
    if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
        local ok, amount = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
        if ok and type(amount) == "number" then
            return amount
        end
    end
    return 0
end


function BT:GetTotalGold()
    local total = 0
    for _, entry in ipairs(self:GetCharacterBreakdown()) do
        total = total + entry.gold
    end
    total = total + self:GetWarbandGold()
    return total
end



function BT:DayKey(t)
    return date("%Y%m%d", t or time())
end

function BT:DayKeyToDate(key)
    local y = tonumber(key:sub(1, 4))
    local m = tonumber(key:sub(5, 6))
    local d = tonumber(key:sub(7, 8))
    return time({ year = y, month = m, day = d, hour = 12 })
end



SLASH_BRUTOSAURTRACKER1 = "/brutosaur"
SLASH_BRUTOSAURTRACKER2 = "/bt"
SlashCmdList["BRUTOSAURTRACKER"] = function(msg)
    if msg == "debug" then
        local fmt = (BT.GUI and BT.GUI.FormatMoney) or tostring
        print("|cff20d947Brutosaur Tracker|r - stored data:")
        local breakdown = BT:GetCharacterBreakdown()
        if #breakdown == 0 then
            print("  (no characters recorded yet)")
        end
        for _, entry in ipairs(breakdown) do
            print(string.format("  %s%s: %s", entry.key, entry.isCurrent and " (this character)" or "", fmt(entry.gold)))
        end
        print("  Warband bank (live): " .. fmt(BT:GetWarbandGold()))
        print("  Total: " .. fmt(BT:GetTotalGold()))
        print("  SavedVariables account folder: " .. tostring(BrutosaurTrackerDB and "loaded" or "MISSING"))
    else
        BT:ToggleMainFrame()
    end
end


local eventFrame = CreateFrame("Frame")
BT.eventFrame = eventFrame

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(eventFrame.RegisterEvent, eventFrame, "ACCOUNT_MONEY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == ADDON_NAME then
            BT:InitDB()
        end
    elseif event == "PLAYER_LOGIN" then
        BT:UpdateCharacterRecord()
        BT:TakeDailySnapshot()
        if BT.RefreshMinimapButton then BT:RefreshMinimapButton() end
        print(string.format("|cff20d947Brutosaur Tracker|r v%s loaded and tracking %s.", BT.VERSION, BT:GetCharDisplayName()))
    elseif event == "PLAYER_ENTERING_WORLD" then
        BT:UpdateCharacterRecord()
    elseif event == "PLAYER_LOGOUT" then
        BT:TakeDailySnapshot()
        local guid = BT:GetCharGUID()
        local rec = guid and BT.db.characters[guid]
        print(string.format("|cff20d947Brutosaur Tracker|r saving now - %s: %s copper (%s)",
            BT:GetCharDisplayName(), rec and tostring(rec.gold) or "?", tostring(guid)))
    elseif event == "PLAYER_MONEY" then
        BT:UpdateCharacterRecord()
        if BT.mainFrame and BT.mainFrame:IsShown() then BT.mainFrame.RefreshAll() end
    elseif event == "ACCOUNT_MONEY" then
        if BT.mainFrame and BT.mainFrame:IsShown() then BT.mainFrame.RefreshAll() end
    end
end)
