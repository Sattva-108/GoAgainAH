-- PlayedTimeSimulator.lua
-- Simulates played time updates for guild members between real updates

local addonName, ns = ...

-- Store simulation data for each character
ns.playedTimeSimulation = ns.playedTimeSimulation or {}

-- Track simulation ticker
local simulationTicker = nil

-- Simulate played time for all active characters
local function UpdateSimulatedPlayedTime()
    -- Only update if SPEED_CLIPS tab is visible
    if not (OFAuctionFrame and OFAuctionFrame:IsShown() and
            OFAuctionFrameDeathClips and OFAuctionFrameDeathClips:IsShown() and
            ns.currentActiveTabId == "SPEED_CLIPS") then
        return
    end

    local currentTime = GetServerTime()
    local updated = false

    for clipID, simData in pairs(ns.playedTimeSimulation) do
        if simData.isActive and simData.lastUpdate then
            local timeDiff = currentTime - simData.lastUpdate
            if timeDiff > 0 then
                -- Find the actual clip and update its simulated played time
                local clips = ns.GetLiveDeathClips()
                local clip = clips[clipID]
                if clip and clip.deathCause == "ALIVE" then
                    -- Don't modify clip.playedTime - GetCurrentPlayedTime() calculates display value
                    updated = true

                    -- Fire event to update UI
                    ns.AuctionHouseAPI:FireEvent(ns.EV_PLAYED_TIME_UPDATED, clipID)
                end
            end
        end
    end

    if updated then
        ns.DebugLog("[PlayedTimeSimulator] Updated simulated display times")
    end
end

-- Get current played time for display (base + elapsed since last update)
function ns.GetCurrentPlayedTime(clip)
    if not clip or not clip.id or clip.deathCause ~= "ALIVE" then
        return clip and clip.playedTime or 0
    end

    local simData = ns.playedTimeSimulation[clip.id]
    if simData and simData.isActive then
        local currentTime = GetServerTime()
        local elapsed = currentTime - simData.startTime
        return simData.basePlayedTime + elapsed
    end

    -- No simulation data, return static played time
    return clip.playedTime or 0
end

-- Start simulation for a character
function ns.StartPlayedTimeSimulation(clip)
    if not clip or not clip.id or clip.deathCause ~= "ALIVE" then
        return
    end

    local currentTime = GetServerTime()

    ns.playedTimeSimulation[clip.id] = {
        isActive = true,
        startTime = currentTime,
        lastUpdate = currentTime,
        basePlayedTime = clip.playedTime or 0,
        characterName = clip.characterName,
        realm = clip.realm
    }

    -- Start the simulation ticker if not already running
    if not simulationTicker then
        simulationTicker = C_Timer:NewTicker(1, UpdateSimulatedPlayedTime)
        ns.DebugLog("[PlayedTimeSimulator] Started simulation ticker")
    end

    ns.DebugLog(string.format("[PlayedTimeSimulator] Started simulation for %s (ID: %s)",
        clip.characterName, clip.id))
end

-- Stop simulation for a character
function ns.StopPlayedTimeSimulation(clipID)
    if ns.playedTimeSimulation[clipID] then
        ns.playedTimeSimulation[clipID].isActive = false
        ns.DebugLog(string.format("[PlayedTimeSimulator] Stopped simulation for clipID: %s", clipID))
    end
end

-- Update simulation base time when real update is received
function ns.UpdatePlayedTimeSimulation(clip)
    if not clip or not clip.id then
        return
    end

    local simData = ns.playedTimeSimulation[clip.id]
    if simData and simData.isActive then
        -- Reset simulation with new base time
        local currentTime = GetServerTime()
        simData.startTime = currentTime
        simData.lastUpdate = currentTime
        simData.basePlayedTime = clip.playedTime or 0

        ns.DebugLog(string.format("[PlayedTimeSimulator] Updated simulation base for %s: %d",
            clip.characterName, clip.playedTime))
    else
        -- Start new simulation
        ns.StartPlayedTimeSimulation(clip)
    end
end

-- Clean up inactive simulations
function ns.CleanupPlayedTimeSimulations()
    local activeCount = 0

    for clipID, simData in pairs(ns.playedTimeSimulation) do
        if simData.isActive then
            -- Check if clip still exists and is ALIVE
            local clips = ns.GetLiveDeathClips()
            local clip = clips[clipID]
            if not clip or clip.deathCause ~= "ALIVE" then
                simData.isActive = false
                ns.DebugLog(string.format("[PlayedTimeSimulator] Deactivated simulation for removed/dead clip: %s", clipID))
            else
                activeCount = activeCount + 1
            end
        end
    end

    -- Stop ticker if no active simulations
    if activeCount == 0 and simulationTicker then
        simulationTicker:Cancel()
        simulationTicker = nil
        ns.DebugLog("[PlayedTimeSimulator] Stopped simulation ticker - no active simulations")
    end
end
