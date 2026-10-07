local ADDON_NAME, BT = ...

local MOUNT_SPELL_IDS = { 264058, 465235, 1313788 } -- Mighty Caravan Brutosaur, Trader's Gilded Brutosaur, Sporebearer Fungal Strider
local SONG = "Interface\\AddOns\\" .. ADDON_NAME .. "\\music\\jurassic_park.mp3"

local mountIDs = {}
local soundHandle

-- we read mount journal's data instead of player aura
local function IsOnTrackedMount()
    if not IsMounted() then return false end
    for _, mountID in ipairs(mountIDs) do
        local _, _, _, isActive = C_MountJournal.GetMountInfoByID(mountID)
        if isActive then return true end
    end
    return false
end

local function Stop()
    if soundHandle then
        StopSound(soundHandle, 500)
        soundHandle = nil
    end
end

local function Update()
    local enabled = BT.db and BT.db.settings.musicEnabled == true
    if enabled and IsOnTrackedMount() then
        if not soundHandle then
            local willPlay, handle = PlaySoundFile(SONG, "Master")
            if willPlay then soundHandle = handle end
        end
    else
        Stop()
    end
end

local frame = CreateFrame("Frame")
BT.UpdateMusic = Update
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        wipe(mountIDs)
        for _, spellID in ipairs(MOUNT_SPELL_IDS) do
            local mountID = C_MountJournal.GetMountFromSpell(spellID)
            if mountID then table.insert(mountIDs, mountID) end
        end
        Stop()
    end
    Update()
end)
