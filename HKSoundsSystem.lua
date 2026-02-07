local addonName, addon = ...
local DBUtils = addon.DBUtils

addon.SoundSystem = {}
local SoundSystem = addon.SoundSystem
local SOUND_CHANNEL = "Master"

SoundSystem.SOUND_MODE = {
    SOUND_PACK   = "sound_pack",
    SINGLE_SOUND = "single_sound",
}

SoundSystem.BASE_SOUNDS = {
    START_GAME = "startgame",
}

SoundSystem.AVAILABLE_SOUND_MODES = {
    { "Sound Pack",  SoundSystem.SOUND_MODE.SOUND_PACK },
    { "Single Sound", SoundSystem.SOUND_MODE.SINGLE_SOUND },
} -- sound_pack_name, string_id -- folder needs to be the same as the string_id

SoundSystem.STREAK_SOUNDS = {
    [1] = "firstblood",
    [2] = "killingspree",
    [3] = "rampage",
    [4] = "dominating",
    [5] = "ultrakill",
    [6] = "unstoppable",
    [7] = "wickedsick",
    [8] = "monsterkill",
    [9] = "godlike",
    [10] = "holysht",
}

SoundSystem.MULTI_KILL_SOUND_NAME = 'multikill'

SoundSystem.AVAILABLE_SOUND_PACKS = {
    { "UT Classic (Female)", 'ut_classic_female' },
    { "UT Classic (Male)", 'ut_classic_male' },
    { "GLaDOS (Portal)", 'glados' },
} -- sound_pack_name, string_id -- folder needs to be the same as the string_id

SoundSystem.AVAILABLE_SINGLE_SOUNDS = {
    { "Gunshot", 'gunshot' },
    { "Gunshot 2", 'gunshot2' },
    { "Murloc", 'murloc' },
    { "Murky (Heroes of the Storm)", 'murky' },
    { "We got him", 'wegothim' },
    { "Bonk", 'bonk' },
    { "Arrow Impact", 'arrowimpact' },
    { "Wilhelm Scream", 'wilhelmscream' },
    { "Boom Headshot", 'boomheadshot' },
    { "Goat Scream", 'goatscream' },
} -- sound name, string_id -- folder needs to be the same as the string_id

-- temp state
local currentSoundPackPreviewIndex = 1

local function buildSoundPath(folder, soundName)
    return string.format(
        "Interface\\AddOns\\%s\\sounds\\%s\\%s.ogg",
        addonName,
        folder,
        soundName
    )
end

local function getActiveSoundFolder()
    local mode = DBUtils.getOptionValue('selectedSoundMode')

    if mode == SoundSystem.SOUND_MODE.SINGLE_SOUND then
        return "single"
    elseif mode == SoundSystem.SOUND_MODE.SOUND_PACK then
        return DBUtils.getOptionValue('selectedSoundPack')
    end
end

function SoundSystem.getSoundPath(soundName)
    if not soundName then return end

    local folder = getActiveSoundFolder()
    return buildSoundPath(folder, soundName)
end

function SoundSystem.play(soundName, userMasterChannel)
    if not soundName then return end

    local path = SoundSystem.getSoundPath(soundName)
    if path then
        if userMasterChannel then
            PlaySoundFile(path, SOUND_CHANNEL)
        else 
            PlaySoundFile(path)
        end
        
    end
end

function SoundSystem.soundExists(soundName)

    if not soundName then return end

    local path = SoundSystem.getSoundPath(soundName)

    local exists = PlaySoundFile(path, SOUND_CHANNEL)
    if exists == nil then
        print('HKSounds - Sound "'.. soundName ..'" does not exist.')
        return false -- instead of nil, return false
    end
    return exists 
end

function SoundSystem.playRandomSingleSound()
    local selected = DBUtils.getOptionValue("selectedSingleSounds") or {}
    local selectedSoundsArray = DBUtils.getSelectedOptionsArray("selectedSingleSounds")

    if #selectedSoundsArray == 0 then return end  -- nothing selected

    local soundName = selectedSoundsArray[math.random(#selectedSoundsArray)]
    SoundSystem.play(soundName)    -- uses your existing play function
end

local function getNextStreakSound()
    local nextSound = SoundSystem.STREAK_SOUNDS[currentSoundPackPreviewIndex]
    if not nextSound then
        nextSound = SoundSystem.STREAK_SOUNDS[1] -- fallback
    end
    return nextSound
end

function SoundSystem.playPreviewStreakSound()
    SoundSystem.play(getNextStreakSound(), true)
    -- increment index
    if currentSoundPackPreviewIndex >= #SoundSystem.STREAK_SOUNDS then
        currentSoundPackPreviewIndex = 1
    else
        currentSoundPackPreviewIndex = currentSoundPackPreviewIndex + 1
    end
end