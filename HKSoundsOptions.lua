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

local function setGroupEnabled(group, enabled, labelFrame)
    for _, child in ipairs({ group:GetChildren() }) do
        setUIEnabled(child, enabled)
    end

    setUIEnabled(labelFrame, enabled)
end

local function CreateInfoIcon(parent, anchorTo, tooltipTitle, tooltipText)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(25, 25)
    icon:SetPoint("LEFT", anchorTo, "RIGHT", 4, 0)

    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\COMMON\\help-i")

    icon:EnableMouse(true)

    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tooltipTitle, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(tooltipText, 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)

    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return icon
end

-- ========= FRAME / EVENTS =========
local function initOptionsFrame()
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

    -- =============================
    -- Sound Mode Section
    -- =============================

    local killingBlowHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    killingBlowHeader:SetPoint("TOPLEFT", 15, -60)
    killingBlowHeader:SetText("Killing Blow Sounds")

    CreateInfoIcon(optionsFrame, killingBlowHeader,
        "Killing Blow Alert",
        "Getting a killing blow plays a sound. Sound packs and different Single sounds are supported."
    )

    local killingBlowSeparator = optionsFrame:CreateTexture(nil, "ARTWORK")
    killingBlowSeparator:SetAtlas("Options_HorizontalDivider", true)
    killingBlowSeparator:SetPoint("TOPLEFT", killingBlowHeader, "BOTTOMLEFT", 0, -4)
    killingBlowSeparator:SetPoint("TOPRIGHT", -15, 0)

    local toggleSoundModeFramesFn = nil -- defined later, used to enable frames after loading saved options

    local soundModeCheckbox = CreateFrame("CheckButton", nil, optionsFrame, "MinimalCheckboxTemplate")
    --soundModeCheckbox:SetPoint("TOPLEFT", xOffset, -75)
    soundModeCheckbox:SetPoint("TOPLEFT", killingBlowHeader, "BOTTOMLEFT", 0, -15)
    soundModeCheckbox:SetChecked(DBUtils.getOptionValue('soundModeEnabled'))
    soundModeCheckbox:SetScript("OnClick", function(self)
        DBUtils.setOptionValue('soundModeEnabled', self:GetChecked())
        addon.refreshEventRegistration()

        if toggleSoundModeFramesFn then
            toggleSoundModeFramesFn()
        end
    end)

    local soundMode = CreateFrame("DropdownButton", nil, optionsFrame, "WowStyle1DropdownTemplate")

    soundMode:SetPoint("LEFT", soundModeCheckbox, "RIGHT", 5, 0)
    soundMode:SetWidth(200)

    -- =============================
    -- Sound Selection Group Box (contains only Sound Pack and Single Sound)
    -- =============================
    local soundGroup = CreateFrame("Frame", nil, optionsFrame, "BackdropTemplate")
    soundGroup:SetPoint("TOPLEFT", xOffset, -120)
    soundGroup:SetPoint("TOPRIGHT", -xOffset, -125) -- right side anchored
    -- soundGroup:SetPoint("TOPLEFT", soundModeCheckbox, "TOPRIGHT", 0, -15)
    soundGroup:SetHeight(140)                       -- keep height fixed

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
    soundPackContainer:SetPoint("TOPLEFT", xOffsetGroup, -35) -- relative to soundGroup
    soundPackContainer:SetSize(370, 30)                       -- width covers dropdown + button, height enough for dropdown


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
        local folder = DBUtils.getOptionValue("selectedSoundPack")
        SoundSystem.playPreviewStreakSound(folder)
    end)

    -- =================
    -- Single Sound Dropdown
    -- =================

    -- Create a container frame for Sound Pack controls
    local singleSoundContainer = CreateFrame("Frame", nil, soundGroup)
    singleSoundContainer:SetPoint("TOPLEFT", xOffsetGroup, -85) -- relative to soundGroup
    singleSoundContainer:SetSize(370, 30)                       -- width covers dropdown + button, height enough for dropdown

    local singleSoundDropdown = CreateFrame("DropdownButton", nil, singleSoundContainer, "WowStyle1DropdownTemplate")
    singleSoundDropdown:SetPoint("TOPLEFT", 0, 0)
    singleSoundDropdown:SetWidth(200)

    MenuUtil.CreateCheckboxMenu(singleSoundDropdown,
        function(value) return DBUtils.getOptionValue('selectedSingleSounds')[value] end,
        function(value)
            local selectedSingleSounds = DBUtils.getOptionValue('selectedSingleSounds')
            if selectedSingleSounds[value] then
                selectedSingleSounds[value] = nil  -- remove from set
            else
                selectedSingleSounds[value] = true -- add to set
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
        local selectedSoundsArray = DBUtils.getSelectedOptionsArray("selectedSingleSounds")
        if #selectedSoundsArray == 0 then return end -- nothing selected

        local randomSoundName = selectedSoundsArray[math.random(#selectedSoundsArray)]
        SoundSystem.playFromFolder(SoundSystem.SINGLE_SOUND_FOLDER_NAME, randomSoundName, true)
    end)

    -- moved to the bottom so it can access all tge frames above
    MenuUtil.CreateRadioMenu(soundMode,
        function(value) return value == DBUtils.getOptionValue('selectedSoundMode') end,
        function(value)
            DBUtils.setOptionValue('selectedSoundMode', value)

            local isSoundPackSelected = value == SoundSystem.SOUND_MODE.SOUND_PACK
            setGroupEnabled(soundPackContainer, isSoundPackSelected, soundPackDropdownLabel)

            local isSingleSoundSelected = value == SoundSystem.SOUND_MODE.SINGLE_SOUND
            setGroupEnabled(singleSoundContainer, isSingleSoundSelected, singleSoundDropdownLabel)
        end,
        unpack(SoundSystem.AVAILABLE_SOUND_MODES)
    )

    toggleSoundModeFramesFn = function()
        local isSoundModeEnabled = DBUtils.getOptionValue('soundModeEnabled')
        setUIEnabled(soundMode, isSoundModeEnabled)
        --setUIEnabled(soundModeLabel, isSoundModeEnabled)

        local selectedSoundMode = DBUtils.getOptionValue('selectedSoundMode')
        if isSoundModeEnabled then
            -- restore state based on saved options
            local isSoundPackSelected = selectedSoundMode == SoundSystem.SOUND_MODE.SOUND_PACK
            setGroupEnabled(soundPackContainer, isSoundPackSelected, soundPackDropdownLabel)

            local isSingleSoundSelected = selectedSoundMode == SoundSystem.SOUND_MODE.SINGLE_SOUND
            setGroupEnabled(singleSoundContainer, isSingleSoundSelected, singleSoundDropdownLabel)
        else
            -- disable all options
            setGroupEnabled(soundPackContainer, false, soundPackDropdownLabel)
            setGroupEnabled(singleSoundContainer, false, singleSoundDropdownLabel)
        end
    end

    -- initial state -> enable/disable frames based on saved options
    toggleSoundModeFramesFn()

    -- =================
    -- Friendly Death Sound Section
    -- =================

    local friendlyDeathHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    friendlyDeathHeader:SetPoint("TOPLEFT", 15, -285)
    friendlyDeathHeader:SetText("Friendly Death Sounds (Arena Only)")

    CreateInfoIcon(optionsFrame, friendlyDeathHeader,
        "Friendly Death Alert (Community asked feature)",
        "Plays a sound when an ally dies in arenas. Requires this option to be enabled and at least one sound selected below."
    )

    local friendlyDeathSeparator = optionsFrame:CreateTexture(nil, "ARTWORK")
    friendlyDeathSeparator:SetAtlas("Options_HorizontalDivider", true)
    friendlyDeathSeparator:SetPoint("TOPLEFT", friendlyDeathHeader, "BOTTOMLEFT", 0, -4)
    friendlyDeathSeparator:SetPoint("TOPRIGHT", -15, 0)


    local toggleFriendlyDeathFramesFn = nil -- defined later, used to enable frames after loading saved options

    local friendlyDeathCheckbox = CreateFrame("CheckButton", nil, optionsFrame, "MinimalCheckboxTemplate")
    friendlyDeathCheckbox:SetPoint("TOPLEFT", friendlyDeathHeader, "BOTTOMLEFT", 0, -15)
    friendlyDeathCheckbox:SetChecked(DBUtils.getOptionValue('friendlyDeathModeEnabled'))
    friendlyDeathCheckbox:SetScript("OnClick", function(self)
        DBUtils.setOptionValue('friendlyDeathModeEnabled', self:GetChecked())
        addon.refreshEventRegistration()

        if toggleFriendlyDeathFramesFn then
            toggleFriendlyDeathFramesFn()
        end
    end)

    -- Create a container frame for Friendly Death Sound controls
    local friendlyDeathModeContainer = CreateFrame("Frame", nil, optionsFrame)
    friendlyDeathModeContainer:SetPoint("LEFT", friendlyDeathCheckbox, "RIGHT", 5, -2)
    friendlyDeathModeContainer:SetSize(370, 30) -- width covers dropdown + button, height enough for dropdown

    local friendlyDeathSoundDropdown = CreateFrame("DropdownButton", nil, friendlyDeathModeContainer,
        "WowStyle1DropdownTemplate")
    friendlyDeathSoundDropdown:SetPoint("TOPLEFT", 0, 0)
    friendlyDeathSoundDropdown:SetWidth(200)

    MenuUtil.CreateCheckboxMenu(friendlyDeathSoundDropdown,
        function(value) return DBUtils.getOptionValue('selectedFriendlyDeathSounds')[value] end,
        function(value)
            local selectedFriendlyDeathSounds = DBUtils.getOptionValue('selectedFriendlyDeathSounds')
            if selectedFriendlyDeathSounds[value] then
                selectedFriendlyDeathSounds[value] = nil  -- remove from set
            else
                selectedFriendlyDeathSounds[value] = true -- add to set
            end
            DBUtils.setOptionValue('selectedFriendlyDeathSounds', selectedFriendlyDeathSounds)
        end,
        unpack(SoundSystem.AVAILABLE_SINGLE_SOUNDS)
    );

    local friendlyDeathSoundPreviewButton = CreateFrame("Button", nil, friendlyDeathModeContainer,
        "UIPanelButtonTemplate")
    friendlyDeathSoundPreviewButton:SetSize(150, 25)
    friendlyDeathSoundPreviewButton:SetPoint("LEFT", friendlyDeathSoundDropdown, "RIGHT", 5, 0)
    friendlyDeathSoundPreviewButton:SetText("Play Sample")
    friendlyDeathSoundPreviewButton:SetScript("OnClick", function()
        local selectedSoundsArray = DBUtils.getSelectedOptionsArray("selectedFriendlyDeathSounds")
        if #selectedSoundsArray == 0 then return end -- nothing selected

        local randomSoundName = selectedSoundsArray[math.random(#selectedSoundsArray)]
        SoundSystem.playFromFolder(SoundSystem.SINGLE_SOUND_FOLDER_NAME, randomSoundName, true)
    end)

    toggleFriendlyDeathFramesFn = function()
        local isFriendlyDeathModeEnabled = DBUtils.getOptionValue('friendlyDeathModeEnabled')
        setGroupEnabled(friendlyDeathModeContainer, isFriendlyDeathModeEnabled)
    end
    toggleFriendlyDeathFramesFn() -- set initial state based on saved options


    -- =================
    -- Enemy Death Sound Section
    -- =================

    local enemyDeathHeader = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enemyDeathHeader:SetPoint("TOPLEFT", 15, -375)
    enemyDeathHeader:SetText("Enemy Death Sounds (Arena Only)")

    CreateInfoIcon(optionsFrame, enemyDeathHeader,
        "Enemy Death Alert (Community asked feature)",
        "Plays a sound when an enemy dies in arenas. Killing Blow Sounds override this event. Requires this option to be enabled and at least one sound selected below."
    )

    local enemyDeathSeparator = optionsFrame:CreateTexture(nil, "ARTWORK")
    enemyDeathSeparator:SetAtlas("Options_HorizontalDivider", true)
    enemyDeathSeparator:SetPoint("TOPLEFT", enemyDeathHeader, "BOTTOMLEFT", 0, -4)
    enemyDeathSeparator:SetPoint("TOPRIGHT", -15, 0)


    local toggleEnemyDeathFramesFn = nil -- defined later, used to enable frames after loading saved options

    local enemyDeathCheckbox = CreateFrame("CheckButton", nil, optionsFrame, "MinimalCheckboxTemplate")
    enemyDeathCheckbox:SetPoint("TOPLEFT", enemyDeathHeader, "BOTTOMLEFT", 0, -15)
    enemyDeathCheckbox:SetChecked(DBUtils.getOptionValue('enemyDeathModeEnabled'))
    enemyDeathCheckbox:SetScript("OnClick", function(self)
        DBUtils.setOptionValue('enemyDeathModeEnabled', self:GetChecked())
        addon.refreshEventRegistration()

        if toggleEnemyDeathFramesFn then
            toggleEnemyDeathFramesFn()
        end
    end)

    -- Create a container frame for Enemy Death Sound controls
    local enemyDeathModeContainer = CreateFrame("Frame", nil, optionsFrame)
    enemyDeathModeContainer:SetPoint("LEFT", enemyDeathCheckbox, "RIGHT", 5, -2)
    enemyDeathModeContainer:SetSize(370, 30) -- width covers dropdown + button, height enough for dropdown

    local enemyDeathSoundDropdown = CreateFrame("DropdownButton", nil, enemyDeathModeContainer,
        "WowStyle1DropdownTemplate")
    enemyDeathSoundDropdown:SetPoint("TOPLEFT", 0, 0)
    enemyDeathSoundDropdown:SetWidth(200)

    MenuUtil.CreateCheckboxMenu(enemyDeathSoundDropdown,
        function(value) return DBUtils.getOptionValue('selectedEnemyDeathSounds')[value] end,
        function(value)
            local selectedEnemyDeathSounds = DBUtils.getOptionValue('selectedEnemyDeathSounds')
            if selectedEnemyDeathSounds[value] then
                selectedEnemyDeathSounds[value] = nil  -- remove from set
            else
                selectedEnemyDeathSounds[value] = true -- add to set
            end
            DBUtils.setOptionValue('selectedEnemyDeathSounds', selectedEnemyDeathSounds)
        end,
        unpack(SoundSystem.AVAILABLE_SINGLE_SOUNDS)
    );

    local enemyDeathSoundPreviewButton = CreateFrame("Button", nil, enemyDeathModeContainer,
        "UIPanelButtonTemplate")
    enemyDeathSoundPreviewButton:SetSize(150, 25)
    enemyDeathSoundPreviewButton:SetPoint("LEFT", enemyDeathSoundDropdown, "RIGHT", 5, 0)
    enemyDeathSoundPreviewButton:SetText("Play Sample")
    enemyDeathSoundPreviewButton:SetScript("OnClick", function()
        local selectedSoundsArray = DBUtils.getSelectedOptionsArray("selectedEnemyDeathSounds")
        if #selectedSoundsArray == 0 then return end -- nothing selected

        local randomSoundName = selectedSoundsArray[math.random(#selectedSoundsArray)]
        SoundSystem.playFromFolder(SoundSystem.SINGLE_SOUND_FOLDER_NAME, randomSoundName, true)
    end)

    toggleEnemyDeathFramesFn = function()
        local isEnemyDeathModeEnabled = DBUtils.getOptionValue('enemyDeathModeEnabled')
        setGroupEnabled(enemyDeathModeContainer, isEnemyDeathModeEnabled)
    end
    toggleEnemyDeathFramesFn() -- set initial state based on saved options
end

-- AddonCompartmentFunc requires a global; export explicitly rather than defining globally
local function openOptionsPanel()
    -- Settings.OpenToCategory throws an error when in-combat
    if UnitAffectingCombat("player") then
        return print(
            '|cffff0000HK|r Sounds: You can’t use this slash command during combat. Please try again once combat has ended.')
    end
    Settings.OpenToCategory(addonCategoryId)
end
_G.openOptionsPanel = openOptionsPanel -- required by AddonCompartmentFunc in HKSounds.toc

loader:SetScript("OnEvent", function(self, event, name)
    if event == OPTIONS_TRACKED_EVENTS.ADDON_LOADED then
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
