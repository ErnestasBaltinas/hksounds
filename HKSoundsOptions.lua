-- =========================================
-- HKSoundsOptions
-- =========================================

-- ========= CONFIG =========
local addonName, addon = ...
local dbName = addonName .. "DB"
local SOUNDS_FOLDER_PATH = "Interface/AddOns/" .. addonName .. "/sounds/"
local loader = CreateFrame("Frame") -- frame to handle events like ADDON_LOADED
local OPTIONS_TRACKED_EVENTS = {
    ADDON_LOADED = "ADDON_LOADED",
}
local xOffset = 7; -- for elements inside the options frame

local availableSoundPacks = {
    { "UT Classic (Female)", 'ut_classic_female' },
    { "UT Classic (Male)", 'ut_classic_male' },
} -- sound_pack_name, string_id -- folder needs to be the same as the string_id

local defaultOptions = {
    selectedSoundPack = availableSoundPacks[1][2]
}

-- ========= STATE =========
local currentPreviewSoundIndex = 1
local addonCategoryId = nil -- mainly used to open options page using slash command

-- ========= HELPERS =========

local function initSavedVars()
    _G[dbName] = _G[dbName] or {}
    _G[dbName].Options = _G[dbName].Options or CopyTable(defaultOptions)
end

local function setOptionValue(id, value)
	_G[dbName].Options[id] = value
end

local function getOptionValue(id)
	return _G[dbName].Options[id]
end

-- ========= SOUND PREVIEW =========
local function getNextSound()
    local nextSound = addon.streakSounds[currentPreviewSoundIndex]

    if nextSound == nil then
        nextSound = 'firstblood' -- fallback value
    end

    return nextSound
end

local function playPreviewSounds()
        local selectedSoundPack = getOptionValue('selectedSoundPack')

        local sameFileName = getNextSound() .. '.ogg'

        local soundPath = SOUNDS_FOLDER_PATH .. selectedSoundPack .. "/" .. sameFileName
        
        PlaySoundFile(soundPath, addon.SOUND_CHANNEL)

        -- handle next sound by updating currentPreviewSoundIndex
        if currentPreviewSoundIndex >= #addon.streakSounds then
            currentPreviewSoundIndex = 1
        else
            currentPreviewSoundIndex = currentPreviewSoundIndex + 1
        end

end
 
-- ========= FRAME / EVENTS =========
local function initOptionsFrame() 
    initSavedVars() -- load local db file

    local optionsFrame = CreateFrame("FRAME", addonName)
	optionsFrame.name = addonName
	local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, addonName)
	Settings.RegisterAddOnCategory(category)
    addonCategoryId = category:GetID()

    local header = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    header:SetPoint("TOPLEFT", xOffset, -20)
    header:SetText(addonName)
    header:SetTextColor(1, 1, 1, 1)

    local separator = optionsFrame:CreateTexture(nil,"ARTWORK")
    separator:SetAtlas("Options_HorizontalDivider",true)
    separator:SetPoint("TOP",0,-50)

    local soundPackDropdown = CreateFrame("DropdownButton", nil, optionsFrame, "WowStyle1DropdownTemplate")
    soundPackDropdown:SetPoint("TOPLEFT", xOffset, -75)
    soundPackDropdown:SetWidth(200)


    MenuUtil.CreateRadioMenu(soundPackDropdown,
        function (value) return value == getOptionValue('selectedSoundPack') end,  -- isSelectedCallback
        function (value) setOptionValue('selectedSoundPack', value) end, -- SetSelected callback
        unpack(availableSoundPacks)
    )

    local soundPackDropdownLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundPackDropdownLabel:SetPoint("BOTTOMLEFT", soundPackDropdown, "TOPLEFT", 0, 2)  -- positions it just above the dropdown
    soundPackDropdownLabel:SetText("Select Sound Pack:")

    -- Preview button
    local previewButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    previewButton:SetSize(150, 25)                -- small square button
    previewButton:SetPoint("LEFT", soundPackDropdown, "RIGHT", 5, 0)  -- 5px to the right
    previewButton:SetText("Play Sample")                     

    previewButton:SetScript("OnClick", function()
        playPreviewSounds()
    end)

end

-- global function for AddonCompartmentFunc
function openOptionsPanel()
    Settings.OpenToCategory(addonCategoryId)
end

loader:SetScript("OnEvent", function(self, event, name)
    if  event == OPTIONS_TRACKED_EVENTS.ADDON_LOADED then
        if name ~= addonName then
            return
        end

        initOptionsFrame()

        loader:UnregisterEvent(OPTIONS_TRACKED_EVENTS.ADDON_LOADED)
    end
end)
loader:RegisterEvent(OPTIONS_TRACKED_EVENTS.ADDON_LOADED)

-- ========= SLASH COMMANDS =========
SLASH_HKSOUNDS1 = "/hks"
SLASH_HKSOUNDS2 = "/hksounds"
SlashCmdList["HKSOUNDS"] = function(params)
   openOptionsPanel()
end 



