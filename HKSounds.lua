-- =========================================
-- HKSounds - UT-style PvP Kill Announcer
-- =========================================

-- ========= Imports =========
local addonName, addon = ...
local SoundSystem = addon.SoundSystem
local DBUtils = addon.DBUtils

-- ========= CONFIG =========
local KILL_RESET_TIME = 5 -- seconds
local SOUND_DELAY = 2

local TRACKED_EVENTS = {
    ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED_NEW_AREA",
    PLAYER_DEAD = "PLAYER_DEAD"
}
local PARTY_KILL = "PARTY_KILL" -- tracked separately basedon the enabled flag
local UNIT_DIED = "UNIT_DIED"   -- tracked separately when in arenas

-- ========= STATE =========
local totalKillsCount = 0;
local killStreak = 0
local multiKill = 0
local killTime = 0
local streakTimer = nil

local deadUnitsInArena = {} -- player, party1, party2, arena1, arena2, arena3 = true

-- ========= HELPERS =========

local function getCurrentTotalKills()
    -- 1487 -- Achievement -> Statistics -> Total Killing Blows
    local _, _, _, _, _, _, _, _, killCount = GetAchievementCriteriaInfoByID(1487, 0)

    return tonumber(killCount)
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

-- ========= KILL STATE MACHINE =========
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

-- ========= ARENA DEATH TRACKER =========
local function markUnitDead(unitId)
    deadUnitsInArena[unitId] = true
end

local function isUnitNewlyDead(unit)
    return ArenaUtil.UnitExists(unit)
        and UnitIsDead(unit)
        and not deadUnitsInArena[unit] == true
end

local function getNewlyDeadFriendlyUnit()
    -- Check player first
    if isUnitNewlyDead("player") then
        return "player"
    end

    -- Check party members (excluding player)
    local playerCount = C_WoWLabsMatchmaking.GetPartySize() - 1
    for i = 1, playerCount do
        local unitId = "party" .. i
        if isUnitNewlyDead(unitId) then
            return unitId
        end
    end

    return nil
end


local function getNewlyDeadEnemyUnit()
    local playerCount = GetNumArenaOpponentSpecs()
    for i = 1, playerCount do
        local unitId = "arena" .. i
        if isUnitNewlyDead(unitId) then
            return unitId
        end
    end

    return nil
end

-- ========= SOUND ENGINE  =========

local function dispatchSoundPackSound(soundName, useMasterChannel)
    local folder = DBUtils.getOptionValue('selectedSoundPack') -- selected sound pack acts like a folder
    SoundSystem.playFromFolder(folder, soundName, useMasterChannel)
end

local function dispatchRandomSound(optionKey, folderName, useMasterChannel)
    local selectedSoundsArray = DBUtils.getSelectedOptionsArray(optionKey)
    if #selectedSoundsArray == 0 then
        return -- nothing selected
    end

    local randomSoundName = selectedSoundsArray[math.random(#selectedSoundsArray)]
    SoundSystem.playFromFolder(folderName, randomSoundName, useMasterChannel)
end

local function dispatchRandomSingleSound(useMasterChannel)
    dispatchRandomSound(
        "selectedSingleSounds",
        SoundSystem.SINGLE_SOUND_FOLDER_NAME,
        useMasterChannel
    )
end

local function dispatchRandomFriendlyDeathSound(useMasterChannel)
    dispatchRandomSound(
        "selectedFriendlyDeathSounds",
        SoundSystem.SINGLE_SOUND_FOLDER_NAME,
        useMasterChannel
    )
end

local function dispatchRandomEnemyDeathSound(useMasterChannel)
    dispatchRandomSound(
        "selectedEnemyDeathSounds",
        SoundSystem.SINGLE_SOUND_FOLDER_NAME,
        useMasterChannel
    )
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

local function handleMultiKills()
    local now = GetTime()
    local multiKillCount, killStreakCount = updateKillCounters(now)

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

local function playKillingBlowSound()
    local soundMode = DBUtils.getOptionValue('selectedSoundMode');
    if soundMode == SoundSystem.SOUND_MODE.SINGLE_SOUND then
        dispatchRandomSingleSound(true)
    elseif soundMode == SoundSystem.SOUND_MODE.SOUND_PACK then
        handleMultiKills()
    end
end

-- ========= EVENT DOMAIN HANDLERS =========
local function handlePartyKill(attackerGUID, targetGUID)
    if not DBUtils.getOptionValue('soundModeEnabled') then
        return
    end

    local killedByPlayer = wasKilledByPlayer(attackerGUID);
    if not killedByPlayer then
        return
    end

    local isTargetHuman = isTargetPlayer(targetGUID)
    if not isTargetHuman then
        return
    end

    playKillingBlowSound()
end

local function handleUnitDeathInArena()
    if DBUtils.getOptionValue('friendlyDeathModeEnabled') then
        local partyUnitDead = getNewlyDeadFriendlyUnit()

        if partyUnitDead then
            markUnitDead(partyUnitDead)
            dispatchRandomFriendlyDeathSound(true)
        end
    end

    -- pseudo code for the next feature
    -- local arenaUnitDead = "arena1" --unit or nil
    -- if arenaUnitDead then
    --     local playerGotKB = true   -- true/false

    --     if playerGotKB then
    --         playKillingBlowSound()
    --     else
    --         local enemyDeathEnabled = true -- true/false
    --         if enemyDeathEnabled then
    --             -- play enemy death sound
    --         end
    --     end

    --     return
    -- end
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

-- ========= EVENT LIFECYCLE MANAGEMENT =========

local function managePartyKillEvent(self)
    if DBUtils.getOptionValue('soundModeEnabled') then
        self:RegisterEvent(PARTY_KILL)
    else
        self:UnregisterEvent(PARTY_KILL)
    end
end

local function manageUnitDiedEvent(self)
    if not DBUtils.getOptionValue('friendlyDeathModeEnabled') then
        if self:IsEventRegistered(UNIT_DIED) then
            self:UnregisterEvent(UNIT_DIED) -- spammy event, Unregister when we dont want to track it
            wipe(deadUnitsInArena)
        end

        return
    end

    if C_PvP.IsMatchConsideredArena() then
        self:RegisterEvent(UNIT_DIED)
    else
        self:UnregisterEvent(UNIT_DIED) -- spammy event, Unregister when we dont want to track it
        wipe(deadUnitsInArena)
    end
end

-- ========= FRAME / ROUTING  =========
local function eventHandler(self, event, ...)
    if event == PARTY_KILL then
        handlePartyKill(...)
    elseif event == TRACKED_EVENTS.PLAYER_DEAD then
        handlePlayerDead()
    elseif event == TRACKED_EVENTS.ZONE_CHANGED_NEW_AREA then
        handleZoneChanged()
        managePartyKillEvent(self)
        manageUnitDiedEvent(self)
    elseif event == UNIT_DIED then
        handleUnitDeathInArena()
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

    managePartyKillEvent(frame)
    manageUnitDiedEvent(frame) -- register UNIT_DIED if in arena and friendly death sounds enabled
end

init()
