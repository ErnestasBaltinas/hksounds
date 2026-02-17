local addonName, addon = ...

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
    { "Sound Pack",   SoundSystem.SOUND_MODE.SOUND_PACK },
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
    { "UT Classic (Male)",   'ut_classic_male' },
    { "GLaDOS (Portal)",     'glados' },
} -- sound_pack_name, string_id -- folder needs to be the same as the string_id

SoundSystem.SINGLE_SOUND_FOLDER_NAME = "single"
SoundSystem.AVAILABLE_SINGLE_SOUNDS = {
    { "Gunshot",                     'gunshot' },
    { "Gunshot 2",                   'gunshot2' },
    { "Gunshot 3 (CS 1.6 AWP)",      'gunshot3' },
    { "Boom Headshot",               'boomheadshot' },
    { "Murloc",                      'murloc' },
    { "Murky (Heroes of the Storm)", 'murky' },
    { "We got him",                  'wegothim' },
    { "Bonk",                        'bonk' },
    { "Arrow Impact",                'arrowimpact' },
    { "Wilhelm Scream",              'wilhelmscream' },
    { "Goat Scream",                 'goatscream' },
} -- sound name, string_id -- folder needs to be the same as the string_id

-- temp state
local currentSoundPackPreviewIndex = 1

function SoundSystem.buildSoundPath(folder, soundName)
    print('folder', folder, 'sound_name', soundName)
    return string.format(
        "Interface\\AddOns\\%s\\sounds\\%s\\%s.ogg",
        addonName,
        folder,
        soundName
    )
end

function SoundSystem.play(soundPath, userMasterChannel)
    if not soundPath then return end

    if soundPath then
        if userMasterChannel then
            PlaySoundFile(soundPath, SOUND_CHANNEL)
        else
            PlaySoundFile(soundPath)
        end
    end
end

-- old and deprecated
-- function SoundSystem.soundExists(soundName)
--     if not soundName then return end

--     local path = SoundSystem.getSoundPath(soundName)

--     local exists = PlaySoundFile(path, SOUND_CHANNEL)
--     if exists == nil then
--         print('HKSounds - Sound "' .. soundName .. '" does not exist.')
--         return false -- instead of nil, return false
--     end
--     return exists
-- end

local function getNextStreakSound()
    local nextSound = SoundSystem.STREAK_SOUNDS[currentSoundPackPreviewIndex]
    if not nextSound then
        nextSound = SoundSystem.STREAK_SOUNDS[1] -- fallback
    end
    return nextSound
end

function SoundSystem.playPreviewStreakSound(folder)
    local soundName = getNextStreakSound()
    local path = SoundSystem.buildSoundPath(folder, soundName);

    SoundSystem.play(path, true)
    -- increment index
    if currentSoundPackPreviewIndex >= #SoundSystem.STREAK_SOUNDS then
        currentSoundPackPreviewIndex = 1
    else
        currentSoundPackPreviewIndex = currentSoundPackPreviewIndex + 1
    end
end

function SoundSystem.getStreakSound(count)
    local maxIndex = #SoundSystem.STREAK_SOUNDS
    return SoundSystem.STREAK_SOUNDS[math.min(maxIndex, count)]
end
