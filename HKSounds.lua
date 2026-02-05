-- =========================================
-- HKSounds - UT-style PvP Kill Announcer
-- =========================================

-- ========= CONFIG =========
local addonName, addon = ...
local dbName = addonName.. 'DB'
local KILL_RESET_TIME = 5 -- seconds
local SOUND_DELAY = 2

local TRACKED_EVENTS = {
    PARTY_KILL = "PARTY_KILL",
    ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED_NEW_AREA",
    PLAYER_DEAD = "PLAYER_DEAD"
}

-- ========= SHARED DATA =========
addon.SOUND_CHANNEL = "Master"

addon.BASE_SOUNDS = {
    START_GAME = "startgame",
}

addon.streakSounds = {
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

addon.multiKillSoundName = 'multikill'

-- ========= STATE =========
local totalKillsCount = 0;
local killStreak = 0
local multiKill = 0
local killTime = 0
local streakTimer = nil

-- ========= HELPERS =========

local function getCurrentTotalKills()

    -- 1487 -- Achievement -> Statistics -> Total Killing Blows
    local _, _, _, _, _, _,_,_, killCount = GetAchievementCriteriaInfoByID(1487, 0)

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



local function getSoundPath(soundName)
    local selectedSoundPack = _G[dbName].Options['selectedSoundPack']
    local SOUNDS_FOLDER_PATH = "Interface\\AddOns\\".. addonName.. "\\sounds\\".. selectedSoundPack .. "\\%s.ogg"
    return string.format(SOUNDS_FOLDER_PATH, soundName)
end

local function resetKillStreak()
    killStreak = 0
    multiKill = 0
    killTime = 0
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

-- ========= SOUND LOOKUP =========
local function getStreakSound(count)
	local maxIndex = #addon.streakSounds
    return addon.streakSounds[math.min(maxIndex, count)]
end

-- ========= SOUND SCHEDULING =========
local function scheduleStreakSound(soundName)
    if streakTimer then
        streakTimer:Cancel()
    end

    streakTimer = C_Timer.NewTimer(SOUND_DELAY, function()
        PlaySoundFile(getSoundPath(soundName)) -- default sound channel
        streakTimer = nil
    end)
end

-- ========= SOUND DISPATCH =========
local function playKillSounds(multiKillCount, killStreakCount)
    local streakSound = getStreakSound(killStreakCount)

    -- play multi-kill immediately
    if multiKillCount > 1 and addon.multiKillSoundName then
        PlaySoundFile(getSoundPath(addon.multiKillSoundName), addon.SOUND_CHANNEL)
    end

    if not streakSound then return end

    -- delay streak only if multi-kill occurred
    if multiKillCount > 1 then
        scheduleStreakSound(streakSound)
    else
        PlaySoundFile(getSoundPath(streakSound), addon.SOUND_CHANNEL)
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


    local now = GetTime()
    local mk, ks = updateKillCounters(now)

    playKillSounds(mk, ks)
end

local function handlePlayerDead()
    resetKillStreak()
end

local function handleZoneChanged()
    if isInPvPInstance() then
        PlaySoundFile(getSoundPath(addon.START_GAME), addon.SOUND_CHANNEL)
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
