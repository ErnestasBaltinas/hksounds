local addonName, addon = ...
local dbName = addonName .. 'DB'

addon.DBUtils = {}
local DBUtils = addon.DBUtils

local defaultOptions = {
    selectedSoundMode = 'sound_pack',
    selectedSoundPack = 'ut_classic_female',
    -- selectedSingleSound =  'bonk', -- deprecated, replaced by selectedSingleSounds
    selectedSingleSounds = { ["gunshot"] = true }
}

function DBUtils.getOptionValue(id)
    return _G[dbName].Options[id]
end

function DBUtils.setOptionValue(id, value)
    _G[dbName].Options[id] = value
end

function DBUtils.getSelectedOptionsArray(optionId)
    local selected = DBUtils.getOptionValue(optionId) or {}

    if type(selected) ~= "table" then
        return nil
    end

    local arr = {}

    for key in pairs(selected) do
        table.insert(arr, key)
    end

    return arr
end

local function applyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = CopyTable(value)
            else
                target[key] = value
            end
        end
    end
end

local function migrateOptions()
    -- deprecated option, convert single string to a lookup table
    if _G[dbName].Options.selectedSingleSound then
        _G[dbName].Options.selectedSingleSounds = {
            [_G[dbName].Options.selectedSingleSound] = true
        }
    end
    -- cleanup old variable
    _G[dbName].Options.selectedSingleSound = nil
end

function DBUtils.initSavedVars()
    _G[dbName] = _G[dbName] or {}
    _G[dbName].Options = _G[dbName].Options or CopyTable(defaultOptions)

    applyDefaults(_G[dbName].Options, defaultOptions)

    migrateOptions()
end
