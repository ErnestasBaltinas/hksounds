local addonName, addon = ...
local dbName = addonName.. 'DB'

addon.DBUtils = {}
local DBUtils = addon.DBUtils

local defaultOptions = {
    selectedSoundMode = 'sound_pack',
    selectedSoundPack = 'ut_classic_female',
    selectedSingleSound = 'gunshot'
}

function DBUtils.getOptionValue(id)
	return _G[dbName].Options[id]
end

function DBUtils.setOptionValue(id, value)
	_G[dbName].Options[id] = value
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

function DBUtils.initSavedVars()
    _G[dbName] = _G[dbName] or {}
    _G[dbName].Options = _G[dbName].Options or CopyTable(defaultOptions)

    applyDefaults(_G[dbName].Options, defaultOptions)
end