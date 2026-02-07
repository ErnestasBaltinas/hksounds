-- =========================================
-- HKSoundsOptions
-- =========================================

-- imports
local addonName, addon = ...
local DBUtils = addon.DBUtils
local SoundSystem = addon.SoundSystem
-- ========= CONFIG =========
local loader = CreateFrame("Frame") -- frame to handle events like ADDON_LOADED
local OPTIONS_TRACKED_EVENTS = {
    ADDON_LOADED = "ADDON_LOADED",
}
local xOffset = 7; -- for elements inside the options frame

-- ========= STATE =========
local addonCategoryId = nil -- mainly used to open options page using slash command

-- ========= HELPERS =========

-- Generic UI enable/disable function
local function setUIEnabled(frame, enabled)
    if not frame then return end
    -- FontString (label)
    if frame:GetObjectType() == "FontString" then
        if enabled then
            frame:SetTextColor(1, 0.82, 0, 1)
        else
            frame:SetTextColor(0.5, 0.5, 0.5)
        end

    -- Button, CheckButton, Dropdown, Slider, etc.
    else
        if enabled then
            if frame.Enable then frame:Enable() end
        else
            if frame.Disable then frame:Disable() end
        end
    end
end

local function setGroupEnabled(group, enabled)
    for _, child in ipairs({group:GetChildren()}) do
        setUIEnabled(child, enabled)
    end
end
 
-- ========= FRAME / EVENTS =========
local function initOptionsFrame()
    DBUtils.initSavedVars() -- load local db file

    local optionsFrame = CreateFrame("FRAME", addonName)
    optionsFrame.name = addonName
    local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, addonName)
    Settings.RegisterAddOnCategory(category)
    addonCategoryId = category:GetID()

    -- Main header
    local header = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    header:SetPoint("TOPLEFT", xOffset, -20)
    header:SetText(addonName)
    header:SetTextColor(1, 1, 1, 1)

    -- Separator
    local separator = optionsFrame:CreateTexture(nil,"ARTWORK")
    separator:SetAtlas("Options_HorizontalDivider", true)
    separator:SetPoint("TOP", 0, -50)

    -- =============================
    -- Sound Mode Dropdown (Top, outside group)
    -- =============================
    local soundMode = CreateFrame("DropdownButton", nil, optionsFrame, "WowStyle1DropdownTemplate")
    soundMode:SetPoint("TOPLEFT", xOffset, -75)
    soundMode:SetWidth(200)

    local soundModeLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundModeLabel:SetPoint("BOTTOMLEFT", soundMode, "TOPLEFT", 0, 2)
    soundModeLabel:SetText("Sound Mode:")

    -- =============================
    -- Sound Selection Group Box (contains only Sound Pack and Single Sound)
    -- =============================
    local soundGroup = CreateFrame("Frame", nil, optionsFrame, "BackdropTemplate")
    soundGroup:SetPoint("TOPLEFT", xOffset, -110)
    soundGroup:SetPoint("TOPRIGHT", -xOffset, -125)  -- right side anchored
    soundGroup:SetHeight(140)  -- keep height fixed

    soundGroup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    soundGroup:SetBackdropColor(0, 0, 0, 0.25)

    local xOffsetGroup = 15

    -- ================
    -- Sound Pack Dropdown
    -- ================

    -- Create a container frame for Sound Pack controls
    local soundPackContainer = CreateFrame("Frame", nil, soundGroup)
    soundPackContainer:SetPoint("TOPLEFT", xOffsetGroup, -35)  -- relative to soundGroup
    soundPackContainer:SetSize(370, 30)  -- width covers dropdown + button, height enough for dropdown


    local soundPackDropdown = CreateFrame("DropdownButton", nil, soundPackContainer, "WowStyle1DropdownTemplate")
    soundPackDropdown:SetPoint("TOPLEFT", 0, 0)
    soundPackDropdown:SetWidth(200)

    MenuUtil.CreateRadioMenu(soundPackDropdown,
        function(value) return value == DBUtils.getOptionValue('selectedSoundPack') end,
        function(value) DBUtils.setOptionValue('selectedSoundPack', value) end,
        unpack(SoundSystem.AVAILABLE_SOUND_PACKS)
    )

    local soundPackDropdownLabel = soundPackContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundPackDropdownLabel:SetPoint("BOTTOMLEFT", soundPackDropdown, "TOPLEFT", 0, 2)
    soundPackDropdownLabel:SetText("Sound Pack:")

    local previewButton = CreateFrame("Button", nil, soundPackContainer, "UIPanelButtonTemplate")
    previewButton:SetSize(150, 25)
    previewButton:SetPoint("LEFT", soundPackDropdown, "RIGHT", 5, 0)
    previewButton:SetText("Play Sample")
    previewButton:SetScript("OnClick", function()
        SoundSystem.playPreviewStreakSound()
    end)
    -- initial state
    local isSoundPackSelected = DBUtils.getOptionValue('selectedSoundMode') == SoundSystem.SOUND_MODE.SOUND_PACK
    
    setGroupEnabled(soundPackContainer, isSoundPackSelected)
    setUIEnabled(soundPackDropdownLabel, isSoundPackSelected)

    -- =================
    -- Single Sound Dropdown
    -- =================

    -- Create a container frame for Sound Pack controls
    local singleSoundContainer = CreateFrame("Frame", nil, soundGroup)
    singleSoundContainer:SetPoint("TOPLEFT", xOffsetGroup, -85)  -- relative to soundGroup
    singleSoundContainer:SetSize(370, 30)  -- width covers dropdown + button, height enough for dropdown

    local singleSoundDropdown = CreateFrame("DropdownButton", nil, singleSoundContainer, "WowStyle1DropdownTemplate")
    singleSoundDropdown:SetPoint("TOPLEFT", 0, 0)
    singleSoundDropdown:SetWidth(200)

    MenuUtil.CreateCheckboxMenu(singleSoundDropdown,
        function(value) return DBUtils.getOptionValue('selectedSingleSounds')[value] end,
        function(value) 
            local selectedSingleSounds = DBUtils.getOptionValue('selectedSingleSounds')
            if selectedSingleSounds[value] then
                selectedSingleSounds[value] = nil   -- remove from set
            else
                selectedSingleSounds[value] = true  -- add to set
            end
            DBUtils.setOptionValue('selectedSingleSounds', selectedSingleSounds)
        end,
        unpack(SoundSystem.AVAILABLE_SINGLE_SOUNDS)
    );

    local singleSoundDropdownLabel = singleSoundContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    singleSoundDropdownLabel:SetPoint("BOTTOMLEFT", singleSoundDropdown, "TOPLEFT", 0, 2)
    singleSoundDropdownLabel:SetText("Single Sound:")

    local singleSoundpreviewButton = CreateFrame("Button", nil, singleSoundContainer, "UIPanelButtonTemplate")
    singleSoundpreviewButton:SetSize(150, 25)
    singleSoundpreviewButton:SetPoint("LEFT", singleSoundDropdown, "RIGHT", 5, 0)
    singleSoundpreviewButton:SetText("Play Sample")
    singleSoundpreviewButton:SetScript("OnClick", function()
        SoundSystem.playRandomSingleSound()
    end)

    local isSingleSoundSelected = DBUtils.getOptionValue('selectedSoundMode') == SoundSystem.SOUND_MODE.SINGLE_SOUND
       -- initial state
    setGroupEnabled(singleSoundContainer, isSingleSoundSelected)
    setUIEnabled(singleSoundDropdownLabel, isSingleSoundSelected)


    -- moved to the bottom so it can access all tge frames above
    MenuUtil.CreateRadioMenu(soundMode,
        function(value) return value == DBUtils.getOptionValue('selectedSoundMode') end,
        function(value) 
            DBUtils.setOptionValue('selectedSoundMode', value)
            
            if value == SoundSystem.SOUND_MODE.SINGLE_SOUND then  -- single_sound
                setGroupEnabled(soundPackContainer, false)
                setUIEnabled(soundPackDropdownLabel, false)
                setGroupEnabled(singleSoundContainer, true)
                setUIEnabled(singleSoundDropdownLabel, true)
            elseif value == SoundSystem.SOUND_MODE.SOUND_PACK then -- sound_pack
                setGroupEnabled(soundPackContainer, true)
                setUIEnabled(soundPackDropdownLabel, true)
                setGroupEnabled(singleSoundContainer, false)
                setUIEnabled(singleSoundDropdownLabel, false)
            end
        end,
        unpack(SoundSystem.AVAILABLE_SOUND_MODES)
    )
end


-- global function for AddonCompartmentFunc
function openOptionsPanel()
    -- Settings.OpenToCategory throws an error when in-combat
    if UnitAffectingCombat("player") then
        return print('|cffff0000HK|r Sounds: You can’t use this slash command during combat. Please try again once combat has ended.')
    end
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

