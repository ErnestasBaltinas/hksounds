-- =========================================
-- HKSounds - UT-style PvP Kill Announcer
-- =========================================

-- imports
local addonName, addon = ...
local SoundSystem = addon.SoundSystem
local DBUtils = addon.DBUtils

-- ========= CONFIG =========
local KILL_RESET_TIME = 5 -- seconds
local SOUND_DELAY = 2

local TRACKED_EVENTS = {
    PARTY_KILL = "PARTY_KILL",
    ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED_NEW_AREA",
    PLAYER_DEAD = "PLAYER_DEAD"
}

-- ========= STATE =========
local totalKillsCount = 0;
local killStreak = 0
local multiKill = 0
local killTime = 0
local streakTimer = nil

-- ========= HELPERS =========

local function getCurrentTotalKills()
    -- 1487 -- Achievement -> Statistics -> Total Killing Blows
    local _, _, _, _, _, _, _, _, killCount = GetAchievementCriteriaInfoByID(1487, 0)

    return killCount
end

local function isInPvPInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end
local function isInOpenWorld()
    local _, instanceType = IsInInstance()
    return instanceType == "none"
end

local function isGUIDSecret(guid)
    return issecretvalue(guid)
end

-- HACKY WORKAROUND:
-- In any instances (arenas/BGs), Blizzard hides attacker GUIDs as <secret>.
-- When the GUID is secret, we infer whether the kill was ours by
-- detecting an increase in the player's total kill counter.
-- This function has side-effects (updates totalKillsCount) by design.
local function wasKilledByPlayer(attackerGUID)
    if isGUIDSecret(attackerGUID) then
        local currentKills = getCurrentTotalKills()

        if currentKills > totalKillsCount then
            totalKillsCount = currentKills
            return true
        end

        return false
    end

    return attackerGUID == UnitGUID("player")
end

-- HACKY WORKAROUND:
-- In any instances instances, Blizzard hides enemy GUIDs as <secret>.
-- When the GUID is secret and we're in a PvP instance, we assume
-- the target is a player (human), since PARTY_KILL only fires for players.
local function isTargetPlayer(targetGUID)
    -- Secret GUIDs cannot be inspected
    if isGUIDSecret(targetGUID) then
        return isInPvPInstance()
    end

    -- Non-secret GUIDs: player GUIDs always start with "Player-"
    return type(targetGUID) == "string" and targetGUID:match("^Player%-") ~= nil
end

-- ========= KILL COUNTERS =========
local function updateKillCounters(now)
    if killTime + KILL_RESET_TIME > now then
        multiKill = multiKill + 1
    else
        multiKill = 1
    end

    killTime = now
    killStreak = killStreak + 1

    return multiKill, killStreak
end

local function resetKillStreak()
    killStreak = 0
    multiKill = 0
    killTime = 0
end

-- ========= SOUND LOGIC =========

local function dispatchRandomSingleSound(useMasterChannel)
    local selectedSoundsArray = DBUtils.getSelectedOptionsArray("selectedSingleSounds")
    if #selectedSoundsArray == 0 then return end -- nothing selected

    local randomSoundName = selectedSoundsArray[math.random(#selectedSoundsArray)]
    SoundSystem.playFromFolder(SoundSystem.SINGLE_SOUND_FOLDER_NAME, randomSoundName, useMasterChannel)
end

local function dispatchSoundPackSound(soundName, useMasterChannel)
    local folder = DBUtils.getOptionValue('selectedSoundPack') -- selected sound pack acts like a folder
    SoundSystem.playFromFolder(folder, soundName, useMasterChannel)
end

local function scheduleStreakSound(soundName)
    if streakTimer then
        streakTimer:Cancel()
    end

    streakTimer = C_Timer.NewTimer(SOUND_DELAY, function()
        dispatchSoundPackSound(soundName, false) -- default sound channel
        streakTimer = nil
    end)
end

local function playKillSounds(multiKillCount, killStreakCount)
    local streakSound = SoundSystem.getStreakSound(killStreakCount)

    -- play multi-kill immediately
    if multiKillCount > 1 and SoundSystem.MULTI_KILL_SOUND_NAME then
        dispatchSoundPackSound(SoundSystem.MULTI_KILL_SOUND_NAME, true)
    end

    if not streakSound then return end

    -- delay streak only if multi-kill occurred
    if multiKillCount > 1 then
        scheduleStreakSound(streakSound)
    else
        dispatchSoundPackSound(streakSound, true)
    end
end

-- ========= EVENT HANDLERS =========
local function handlePartyKill(attackerGUID, targetGUID)
    local killedByPlayer = wasKilledByPlayer(attackerGUID);
    local isTargetHuman = isTargetPlayer(targetGUID)

    if not killedByPlayer then
        return
    end

    if not isTargetHuman then
        return
    end

    local soundMode = DBUtils.getOptionValue('selectedSoundMode');
    if soundMode == SoundSystem.SOUND_MODE.SINGLE_SOUND then
        dispatchRandomSingleSound(true)
    elseif soundMode == SoundSystem.SOUND_MODE.SOUND_PACK then
        local now = GetTime()
        local mk, ks = updateKillCounters(now)

        playKillSounds(mk, ks)
    end
end

local function handlePlayerDead()
    resetKillStreak()
end

local function handleZoneChanged()
    if isInPvPInstance() then
        local soundMode = DBUtils.getOptionValue('selectedSoundMode');
        if soundMode == SoundSystem.SOUND_MODE.SOUND_PACK then
            dispatchSoundPackSound(SoundSystem.BASE_SOUNDS.START_GAME, true)
        end
    end
    resetKillStreak()
end

-- ========= FRAME / EVENTS =========
local function eventHandler(self, event, ...)
    if event == TRACKED_EVENTS.PARTY_KILL then
        handlePartyKill(...)
    elseif event == TRACKED_EVENTS.PLAYER_DEAD then
        handlePlayerDead()
    elseif event == TRACKED_EVENTS.ZONE_CHANGED_NEW_AREA then
        handleZoneChanged()
    end
end

local function init()
    -- Initialize baseline kill count.
    -- Used as a heuristic to infer player kills when PvP GUIDs are hidden (<secret>)
    -- in arenas and battlegrounds.
    totalKillsCount = getCurrentTotalKills()

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", eventHandler)

    for _, eventName in pairs(TRACKED_EVENTS) do
        frame:RegisterEvent(eventName)
    end
end

init()
