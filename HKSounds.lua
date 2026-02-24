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
    PLAYER_DEAD = "PLAYER_DEAD",
    PLAYER_LOGIN = "PLAYER_LOGIN"
}
local PARTY_KILL = "PARTY_KILL"                             -- tracked separately basedon the enabled flag
local UNIT_DIED = "UNIT_DIED"                               -- tracked separately when in arenas
local UPDATE_BATTLEFIELD_SCORE = "UPDATE_BATTLEFIELD_SCORE" -- registered transiently in BGs

-- ========= STATE =========
local frame                      -- elevated to module scope so domain handlers can register events
local previousBGKillingBlows = 0 -- rolling BG KB count; updated each time score data arrives

local totalKillsCount = 0;
local killStreak = 0
local multiKill = 0
local killTime = 0
local streakTimer = nil

local deadUnitsInArena = {} -- player, party1, party2, arena1, arena2, arena3 = true

-- ========= HELPERS =========

local function getCurrentTotalKills()
    -- 1487 -- Achievement -> Statistics -> Total Killing Blows
    local _, _, _, killCount = GetAchievementCriteriaInfoByID(1487, 0)

    return killCount
end

local function syncTotalKills()
    local current = getCurrentTotalKills()
    if current ~= nil and current ~= totalKillsCount then
        totalKillsCount = current
    end
end

local function isInPvPInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end
local function isInOpenWorld()
    local _, instanceType = IsInInstance()
    return instanceType == "none"
end

local function getBGKillingBlows()
    local playerName = UnitName("player")
    local numScores = GetNumBattlefieldScores()
    for i = 1, numScores do
        local name, killingBlows = GetBattlefieldScore(i)
        if name == playerName then
            return killingBlows
        end
    end
    return nil
end

local function isInBattleground()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp"
end

local function isInArena()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "arena"
end

local function resetBGKillTracking()
    previousBGKillingBlows = 0
    frame:UnregisterEvent(UPDATE_BATTLEFIELD_SCORE) -- safe no-op if not registered
end

local function isGUIDSecret(guid)
    return issecretvalue(guid)
end

-- HACKY WORKAROUND:
-- In any instances (arenas/BGs), Blizzard hides attacker GUIDs as <secret>.
-- When the GUID is secret, we infer whether the kill was ours by
-- detecting an increase in the player's total kill counter.
local function wasKilledByPlayer(attackerGUID)
    if isGUIDSecret(attackerGUID) then
        local current = getCurrentTotalKills()
        -- GetAchievementCriteriaInfoByID can return nil if data isn't loaded yet; comparison against nil would error
        if current == nil or totalKillsCount == nil then return false end
        return current > totalKillsCount
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
-- KB detection varies by environment due to Blizzard hiding GUIDs in instances:
--   Open world  : PARTY_KILL → GUID match        → play sound
--   Battleground: PARTY_KILL → scoreboard delta   → play sound  (async via UPDATE_BATTLEFIELD_SCORE)
--   Arena       : UNIT_DIED  → achievement delta  → play sound
local function handlePartyKill(attackerGUID, targetGUID)
    if isInArena() then return end -- arena handled by UNIT_DIED

    if not DBUtils.getOptionValue('soundModeEnabled') then
        return
    end

    -- Guard must stay before the BG branch: PARTY_KILL fires for all party member kills.
    -- Without this, every teammate kill in a BG would trigger RequestBattlefieldScoreData().
    local killedByPlayer = wasKilledByPlayer(attackerGUID)
    if not killedByPlayer then
        return
    end

    if not isTargetPlayer(targetGUID) then
        return
    end

    if isInBattleground() then
        frame:RegisterEvent(UPDATE_BATTLEFIELD_SCORE)
        RequestBattlefieldScoreData()
    else
        playKillingBlowSound()
    end
end

local function handleBattlefieldScoreUpdate(self)
    self:UnregisterEvent(UPDATE_BATTLEFIELD_SCORE)

    local currentKBs = getBGKillingBlows()
    if currentKBs and currentKBs > previousBGKillingBlows then
        playKillingBlowSound()
    end

    previousBGKillingBlows = currentKBs or previousBGKillingBlows
end

local function handleUnitDeathInArena()
    -- Friendly death detection
    if DBUtils.getOptionValue('friendlyDeathModeEnabled') then
        local partyUnitDead = getNewlyDeadFriendlyUnit()
        if partyUnitDead then
            markUnitDead(partyUnitDead)
            dispatchRandomFriendlyDeathSound(true)
        end
    end

    -- Arena kill detection: always detect and bookkeep, regardless of settings
    local enemyUnitDead = getNewlyDeadEnemyUnit()
    local current = getCurrentTotalKills()
    local playerGotKill = current ~= nil and totalKillsCount ~= nil and current > totalKillsCount

    if enemyUnitDead then markUnitDead(enemyUnitDead) end

    -- Killing blow sound: player got the KB
    if enemyUnitDead and playerGotKill and DBUtils.getOptionValue('soundModeEnabled') then
        playKillingBlowSound()
    end

    -- Enemy death sound: enemy died but player did not get the KB
    if enemyUnitDead and not playerGotKill and DBUtils.getOptionValue('enemyDeathModeEnabled') then
        dispatchRandomEnemyDeathSound(true)
    end
end

local function handlePlayerDead()
    resetKillStreak()
end

local function handleZoneChanged()
    resetBGKillTracking()

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
    local anyFeatureEnabled = DBUtils.getOptionValue('soundModeEnabled')
        or DBUtils.getOptionValue('friendlyDeathModeEnabled')
        or DBUtils.getOptionValue('enemyDeathModeEnabled')

    if not anyFeatureEnabled then
        if self:IsEventRegistered(UNIT_DIED) then
            self:UnregisterEvent(UNIT_DIED) -- spammy event, unregister when we dont want to track it
            wipe(deadUnitsInArena)
        end
        return
    end

    if isInArena() then
        self:RegisterEvent(UNIT_DIED)
    else
        self:UnregisterEvent(UNIT_DIED) -- spammy event, unregister when we dont want to track it
        wipe(deadUnitsInArena)
    end
end

-- ========= FRAME / ROUTING  =========
local function eventHandler(self, event, ...)
    if event == PARTY_KILL then
        handlePartyKill(...)
        syncTotalKills()
    elseif event == TRACKED_EVENTS.PLAYER_LOGIN then
        syncTotalKills()
    elseif event == TRACKED_EVENTS.PLAYER_DEAD then
        handlePlayerDead()
    elseif event == TRACKED_EVENTS.ZONE_CHANGED_NEW_AREA then
        handleZoneChanged()
        managePartyKillEvent(self)
        manageUnitDiedEvent(self)
        syncTotalKills()
    elseif event == UNIT_DIED then
        handleUnitDeathInArena()
        syncTotalKills()
    elseif event == UPDATE_BATTLEFIELD_SCORE then
        handleBattlefieldScoreUpdate(self)
    end
end

local function init()
    DBUtils.initSavedVars() -- load local db file

    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", eventHandler)

    for _, eventName in pairs(TRACKED_EVENTS) do
        frame:RegisterEvent(eventName)
    end

    managePartyKillEvent(frame)
    manageUnitDiedEvent(frame) -- register UNIT_DIED if in arena and friendly death sounds enabled
end

init()
