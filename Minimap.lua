local ADDON_NAME, BT = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

if not LDB or not LDBIcon then
    function BT:RefreshMinimapButton() end
    return
end

local dataObject = LDB:NewDataObject(ADDON_NAME, {
    type = "launcher",
    text = "Brutosaur Tracker",
    icon = BT.ICON,
    OnClick = function(_, mouseButton)
        BT:ToggleMainFrame()
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Brutosaur Tracker")
        tooltip:AddLine("|cffffffffLeft-click:|r Open window", 1, 1, 1)
        tooltip:AddLine("|cffffffffDrag:|r Move this button", 1, 1, 1)
    end,
})

function BT:RefreshMinimapButton()
    if not LDBIcon:IsRegistered(ADDON_NAME) then
        LDBIcon:Register(ADDON_NAME, dataObject, self.db.settings.minimap)
    end

    if self.db.settings.minimap.hide then
        LDBIcon:Hide(ADDON_NAME)
    else
        LDBIcon:Show(ADDON_NAME)
    end
end
