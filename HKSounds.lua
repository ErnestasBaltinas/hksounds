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
    PLAYER_DEAD = "PLAYER_DEAD",
}

local UNIT_DIED = "UNIT_DIED" -- tracked separately when in arenas

-- ========= STATE =========
local totalKillsCount = 0;
local killStreak = 0
local multiKill = 0
local killTime = 0
local streakTimer = nil

local deadUnits = {} -- player, party1, party2, arena1, arena2, etc. -> true

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

local function isInArena()
    local _, instanceType = IsInInstance()
    return instanceType == "arena"
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

local function setUnitDead(unitId)
    deadUnits[unitId] = true
    print("Marked unit", unitId, "as dead.")
end

local function isUnitAlreadyDead(unitId)
    return deadUnits[unitId] == true
end
-- ========= SOUND LOOKUP =========
local function getStreakSound(count)
    local maxIndex = #SoundSystem.STREAK_SOUNDS
    return SoundSystem.STREAK_SOUNDS[math.min(maxIndex, count)]
end

-- ========= SOUND SCHEDULING =========
local function scheduleStreakSound(soundName)
    if streakTimer then
        streakTimer:Cancel()
    end

    streakTimer = C_Timer.NewTimer(SOUND_DELAY, function()
        SoundSystem.play(soundName, false) -- default sound channel
        streakTimer = nil
    end)
end

-- ========= SOUND DISPATCH =========
local function playKillSounds(multiKillCount, killStreakCount)
    local streakSound = getStreakSound(killStreakCount)

    -- play multi-kill immediately
    if multiKillCount > 1 and SoundSystem.MULTI_KILL_SOUND_NAME then
        SoundSystem.play(SoundSystem.MULTI_KILL_SOUND_NAME, true)
    end

    if not streakSound then return end

    -- delay streak only if multi-kill occurred
    if multiKillCount > 1 then
        scheduleStreakSound(streakSound)
    else
        SoundSystem.play(streakSound, true)
    end
end

-- ========= EVENT HANDLERS =========

local function handleKillingBlowInArena()
    local deadUnit = nil
    local opponentPlayerCount = GetNumArenaOpponentSpecs()
    for i = 1, opponentPlayerCount do
        local unitId = "arena" .. i
        if ArenaUtil.UnitExists(unitId) and UnitIsDead(unitId) and not isUnitAlreadyDead(unitId) then
            deadUnit = unitId
            setUnitDead(unitId)
            return true
        end
    end

    if deadUnit then
        local soundMode = DBUtils.getOptionValue('selectedSoundMode');
        if soundMode == SoundSystem.SOUND_MODE.SINGLE_SOUND then
            SoundSystem.playRandomSingleSound()
        elseif soundMode == SoundSystem.SOUND_MODE.SOUND_PACK then
            local now = GetTime()
            local mk, ks = updateKillCounters(now)

            playKillSounds(mk, ks)
        end
    end
end

local function handleKillingBlow(targetGUID)
    local isTargetHuman = isTargetPlayer(targetGUID)
    if not isTargetHuman then
        return
    end

    local soundMode = DBUtils.getOptionValue('selectedSoundMode');
    if soundMode == SoundSystem.SOUND_MODE.SINGLE_SOUND then
        SoundSystem.playRandomSingleSound()
    elseif soundMode == SoundSystem.SOUND_MODE.SOUND_PACK then
        local now = GetTime()
        local mk, ks = updateKillCounters(now)

        playKillSounds(mk, ks)
    end
end

local function handleArenaOpponentDeath()
    if not DBUtils.getOptionValue('enemyDeathModeEnabled') then
        return
    end
    local function isAnyArenaOpponentDead()
        local opponentPlayerCount = GetNumArenaOpponentSpecs()

        for i = 1, opponentPlayerCount do
            local unitId = "arena" .. i


            -- revive or hunter Feign Death
            if isUnitAlreadyDead(unitId) and not UnitIsDeadOrGhost(unitId) then
                deadUnits[unitId] = nil -- reset state
            end

            if ArenaUtil.UnitExists(unitId) and UnitIsDeadOrGhost(unitId) and not isUnitAlreadyDead(unitId) then
                return unitId
            end
        end

        return nil
    end

    local deadOpponentUnit = isAnyArenaOpponentDead()
    if deadOpponentUnit ~= nil then
        setUnitDead(deadOpponentUnit)
        SoundSystem.playRandomEnemyDeathSound()
    end
end

local function handlePartyKill(attackerGUID, targetGUID)
    local killedByPlayer = wasKilledByPlayer(attackerGUID);

    print("PARTY_KILL 1")

    if DBUtils.getOptionValue('soundModeEnabled') and killedByPlayer then
        print("PARTY_KILL 2")

        -- if C_PvP.IsMatchConsideredArena() then
        --     handleKillingBlowInArena()
        -- else

        -- end
        handleKillingBlow(targetGUID) -- bgs and open world
        -- if sound mode and enemy death mode are both disabled, do not play any sounds
    end
end

local function handlePlayerDead()
    resetKillStreak()
end



-- Handle friendly deaths in arenas
local function handlePartyDeath()
    if not DBUtils.getOptionValue('friendlyDeathModeEnabled') then
        return
    end

    -- check if player died
    if ArenaUtil.UnitExists("player") and UnitIsDead("player") and not isUnitAlreadyDead("player") then
        SoundSystem.playRandomFriendlyDeathSound()
        setUnitDead("player")
        return true
    end

    local partyPlayerCount = C_WoWLabsMatchmaking.GetPartySize() - 1 -- exclude player from count
    for i = 1, partyPlayerCount do
        local unitId = "party" .. i
        -- print("handlePartyDeath - Checking unit", unitId, "exists?", ArenaUtil.UnitExists(unitId), "isDead?",
        --     UnitIsDead(unitId),
        --     "alreadyDead?", isUnitAlreadyDead(unitId))
        if ArenaUtil.UnitExists(unitId) and UnitIsDead(unitId) and not isUnitAlreadyDead(unitId) then
            setUnitDead(unitId)
            SoundSystem.playRandomFriendlyDeathSound()

            return true
        end
    end
end

local function manageUnitDiedEvent(self)
    if C_PvP.IsMatchConsideredArena() and DBUtils.getOptionValue('enemyDeathModeEnabled') then
        self:RegisterEvent(UNIT_DIED)
    else
        self:UnregisterEvent(UNIT_DIED)
        wipe(deadUnits)
    end
end


local function handleZoneChanged()
    if isInPvPInstance() then
        local soundMode = DBUtils.getOptionValue('selectedSoundMode');
        if soundMode == SoundSystem.SOUND_MODE.SOUND_PACK and DBUtils.getOptionValue('soundModeEnabled') then
            SoundSystem.play(SoundSystem.BASE_SOUNDS.START_GAME, true)
        end
    end
    resetKillStreak()
end

-- ========= FRAME / EVENTS =========
local function eventHandler(self, event, ...)
    if event == TRACKED_EVENTS.PARTY_KILL then
        --print("PARTY_KILL event fired")
        handlePartyKill(...)
    elseif event == TRACKED_EVENTS.PLAYER_DEAD then
        handlePlayerDead()
    elseif event == TRACKED_EVENTS.ZONE_CHANGED_NEW_AREA then
        handleZoneChanged()
        manageUnitDiedEvent(self)
    elseif event == UNIT_DIED then
        handlePartyDeath()
        handleArenaOpponentDeath()
    end
end

local function init()
    DBUtils.initSavedVars() -- load local db file
    -- Initialize baseline kill count.
    -- Used as a heuristic to infer player kills when PvP GUIDs are hidden (<secret>)
    -- in arenas and battlegrounds.
    totalKillsCount = getCurrentTotalKills()

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", eventHandler)

    for _, eventName in pairs(TRACKED_EVENTS) do
        frame:RegisterEvent(eventName)
    end

    manageUnitDiedEvent(frame) -- register UNIT_DIED if in arena and friendly death sounds enabled
end

init()


function testPrint()
    print("--------------testPrint - -----------")
    print('GetNumArenaOpponentSpecs()', GetNumArenaOpponentSpecs());
end
