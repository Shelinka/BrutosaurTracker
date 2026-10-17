local ADDON_NAME, BT = ...

local MOUNT_SPELL_ID = 1313788 -- Sporebearer Fungal Strider
local NPC_ID = 273832          -- Hoshena
local SESSION_TIMEOUT = 20

local PASSENGERS = {
    { key = "AUCTIONEER", label = "Auctioneer",          match = "auctioneer" },
    { key = "MAIL",       label = "Mail Courier",        match = "mail" },
    { key = "VENDOR",     label = "Vendor and Repairs",  match = "vendor" },
    { key = "TRANSMOG",   label = "Transmogrifier",      match = "transmog" },
    { key = "NONE",       label = "Unoccupied",          match = "unoccupied" },
}

local function PassengerByKey(key)
    for _, p in ipairs(PASSENGERS) do
        if p.key == key then return p end
    end
end

local function GetSettings()
    if not BT.db then return nil end
    BT.db.strider = BT.db.strider or {}
    return BT.db.strider
end

local function HasMount()
    if not (C_MountJournal and C_MountJournal.GetMountFromSpell) then return false end
    local mountID = C_MountJournal.GetMountFromSpell(MOUNT_SPELL_ID)
    if not mountID then return false end
    local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    return isCollected == true
end

local function GetNPCID()
    local guid = UnitGUID("npc")
    if type(guid) ~= "string" then return nil end
    local unitType, _, _, _, _, id = strsplit("-", guid)
    if unitType ~= "Creature" then return nil end
    return tonumber(id)
end


local configFrame

local function CreateSeatDropdown(parent, label, seat, y)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 20, y)
    text:SetText(label)

    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", 20, y - 18)
    dd:SetWidth(240)
    dd:SetupMenu(function(_, root)
        for _, p in ipairs(PASSENGERS) do
            root:CreateRadio(p.label,
                function() return GetSettings()[seat] == p.key end,
                function() GetSettings()[seat] = p.key end)
        end
    end)
    return dd
end

function BT:OpenStriderConfig()
    local s = GetSettings()
    if not s then return end
    s.left = s.left or "NONE"
    s.right = s.right or "NONE"

    if not configFrame then
        local f = CreateFrame("Frame", "BrutosaurTrackerStriderConfig", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(280, 190)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f.TitleText:SetText("Fungal Strider Seats")
        tinsert(UISpecialFrames, f:GetName())

        f.left = CreateSeatDropdown(f, "Left Seat option:", "left", -35)
        f.right = CreateSeatDropdown(f, "Right Seat option:", "right", -90)

        local done = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        done:SetSize(100, 24)
        done:SetPoint("BOTTOM", 0, 12)
        done:SetText("Done")
        done:SetScript("OnClick", function() f:Hide() end)

        configFrame = f
    end

    s.enabled = true
    s.asked = true
    configFrame.left:GenerateMenu()
    configFrame.right:GenerateMenu()
    configFrame:Show()
end

StaticPopupDialogs["BRUTOSAUR_STRIDER_AUTOMATE"] = {
    text = "Brutosaur Tracker: Do you want to automate the Fungal Strider seat configuration on all characters?",
    button1 = YES,
    button2 = NO,
    OnAccept = function() BT:OpenStriderConfig() end,
    OnCancel = function()
        local s = GetSettings()
        if s then s.asked = true; s.enabled = false end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}


local done = {}
local pending
local lastActivity = 0

local function FindOption(options, text)
    for _, opt in ipairs(options) do
        if opt.name and opt.name:lower():find(text, 1, true) then return opt end
    end
end

local function Select(opt)
    lastActivity = GetTime()
    C_GossipInfo.SelectOption(opt.gossipOptionID)
end

local function OnGossipShow()
    local s = GetSettings()
    if not s then return end
    local npcID = GetNPCID()
    if npcID ~= NPC_ID or not HasMount() then return end

    if not s.asked then
        s.asked = true
        StaticPopup_Show("BRUTOSAUR_STRIDER_AUTOMATE")
        return
    end
    if not s.enabled or IsShiftKeyDown() then return end

    if GetTime() - lastActivity > SESSION_TIMEOUT then
        wipe(done)
        pending = nil
    end

    local options = C_GossipInfo.GetOptions() or {}

    if pending then
        local want = PassengerByKey(s[pending])
        local opt = want and FindOption(options, want.match)
        if opt then
            local seat = pending
            done[seat] = true
            pending = nil
            Select(opt)
            if seat == "left" and not done.right then
                print("|cff20d947Brutosaur Tracker|r - Strider left seat selected, interact again to add the second one.")
            elseif seat == "right" then
                print("|cff20d947Brutosaur Tracker|r - Strider right seat selected.")
            else
                print("|cff20d947Brutosaur Tracker|r - Strider left seat selected.")
            end
            return
        end
    end

    for _, seat in ipairs({ "left", "right" }) do
        if not done[seat] then
            local opt = FindOption(options, seat .. " seat")
            if opt then
                pending = seat
                Select(opt)
            end
            return
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_CLOSED" then
        if done.left and done.right then
            wipe(done)
            pending = nil
        end
    else
        OnGossipShow()
    end
end)
