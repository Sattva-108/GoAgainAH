local _, ns = ...

AuctionHouseDBSaved = AuctionHouseDBSaved or {}


------------------------------------------------------------------------
-- >>> REALM SUPPORT
------------------------------------------------------------------------
local fullName = GetRealmName() or ""
ns.CURRENT_REALM_CODE = ns.RealmFullNameToID[fullName] or 0
ns.CURRENT_REALM      = fullName                    -- ← NEW

-- Filter helper ----------------------------------------------
function ns.FilterClipsThisRealm(pool)
    local filtered = {}
    for _, clip in pairs(pool) do
        -- use the string field we now keep
        if clip.realm == ns.CURRENT_REALM then
            table.insert(filtered, clip)
        end
    end
    return filtered
end

------------------------------------------------------------------------


-- Define the global queue table to track both completed and death event characters
local queue = {}

-- Expose queue access for external modules
ns.AddClipToQueue = function(clip)
    -- Only queue clips that still need playedTime and haven't failed lookup
    if not clip or clip.playedTime or clip.deathCause == "ALIVE" or clip.getPlayedTry == "failed" then
        return
    end

    -- Ensure per-player queue table exists
    local name = clip.characterName or "?"
    queue[name] = queue[name] or {}
    local playerQueue = queue[name]

    -- Deduplicate by clip.id (most reliable) – skip if already queued
    if clip.id then
        for _, existing in ipairs(playerQueue) do
            if existing.id == clip.id then
                -- Optional debug: duplicate detected
                --print(string.format("[QUEUE %s] Duplicate clip ignored for %s (id=%s)", date("%M:%S"), name, clip.id))
                return
            end
        end
    end

    -- Safe-guard initial state
    clip.getPlayedTry = clip.getPlayedTry or 0

    table.insert(playerQueue, clip)
    -- Optional debug: successful enqueue
--    print(string.format("[QUEUE %s] Added clip for %s (id=%s). Queue size=%d", date("%M:%S"), name, clip.id or "nil", #playerQueue))
end

local races = {
    [1] = { name = "Человек", faction = "Alliance" },
    [2] = { name = "Орк", faction = "Horde" },
    [3] = { name = "Дворф", faction = "Alliance" },
    [4] = { name = "Ночной эльф", faction = "Alliance" },
    [5] = { name = "Нежить", faction = "Horde" },
    [6] = { name = "Таурен", faction = "Horde" },
    [7] = { name = "Гном", faction = "Alliance" },
    [8] = { name = "Тролль", faction = "Horde" },
    [9] = { name = "Гоблин", faction = "Horde" },
    [10] = { name = "Эльф крови", faction = "Horde" },
    [11] = { name = "Дреней", faction = "Alliance" },
    [12] = { name = "Ворген", faction = "Alliance" },
    [13] = { name = "Нага", faction = "Horde" },
    [14] = { name = "Пандарен", faction = "Alliance" },
    [15] = { name = "Высший эльф", faction = "Alliance" },
    [16] = { name = "Пандарен", faction = "Horde" },
    [17] = { name = "Ночноро\nждённый", faction = "Horde" },
    [18] = { name = "Эльф Бездны", faction = "Alliance" },
    [19] = { name = "Вульпера", faction = "Alliance" },
    [20] = { name = "Вульпера", faction = "Horde" },
    [21] = { name = "Вульпера", faction = "Neutral" },
    [22] = { name = "Пандарен", faction = "Neutral" },
    [23] = { name = "Зандалар", faction = "Horde" },
    [24] = { name = "Озар. дреней", faction = "Alliance" },
    [25] = { name = "Эредар", faction = "Horde" },
    [26] = { name = "Дворф Ч. Железа", faction = "Alliance" },
    [27] = { name = "Драктир", faction = "Horde" }
}


-- Define class mappings
local classes = {
    [8] = "MAGE",
    [7] = "SHAMAN",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [1] = "WARRIOR",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [11] = "DRUID",
    [9] = "WARLOCK" -- Corrected class ID for Warlock
}

-- Death cause mappings
local deathCauses = {
    [0] = "Усталость",
    [1] = "Утопление",
    [2] = "Падение",
    [3] = "Лава",
    [4] = "Слизь",
    [5] = "Огонь",
    [6] = "Падение в бездну",
    [7] = "существом",
    [8] = "Умер в PVP схватке",
    [9] = "Погиб от действий союзника",
    [10] = "Погиб от собственных действий",
}

--- Generates a unique clip ID.
--- @param clip table  The clip object (must have characterName, level, faction, where, deathCause)
--- @param isCompleted boolean  True if this is a completed clip
function ns.GenerateClipID(clip, isCompleted)
    local parts = {
        clip.characterName,
        -- clip.level, -- Уровень будет добавлен условно ниже
        clip.faction,
    }
    if not isCompleted then
        if clip.deathCause == "ALIVE" then
            -- Для живых: не включаем зону и УРОВЕНЬ, только признак ALIVE
            parts[#parts+1] = "ALIVE"
        else
            -- Для обычных смертей: добавляем УРОВЕНЬ, зону и причину
            parts[#parts+1] = clip.level -- <<<< УРОВЕНЬ ДОБАВЛЯЕТСЯ ЗДЕСЬ
            parts[#parts+1] = clip.where
            parts[#parts+1] = clip.deathCause
        end
    else
        -- Для completed клипов (если такие будут), также добавляем уровень
        parts[#parts+1] = clip.level -- <<<< И ЗДЕСЬ
        -- Можно добавить другие части для completed, если нужно
    end
    return table.concat(parts, "-")
end

ns.GetLiveDeathClips = function()
    if LiveDeathClips == nil then
        LiveDeathClips = {}
    end
    return LiveDeathClips
end

ns.GetLastDeathClipTimestamp = function()
    local ts = 0
    for _, clip in pairs(ns.FilterClipsThisRealm(ns.GetLiveDeathClips())) do
        ts = math.max(ts, clip.ts or 0)
    end
    return ts
end

ns.GetNewDeathClips = function(since, existing)
    local allClips = ns.GetLiveDeathClips()

    -- FULL‐SYNC: if since is zero or nil, return every clip unfiltered
    if not since or since == 0 then
        local full = {}
        for _, clip in pairs(allClips) do
            full[#full+1] = clip
        end
        table.sort(full, function(a, b) return (a.ts or 0) < (b.ts or 0) end)
        return full
    end

    -- Otherwise, do the normal incremental sync logic:

    -- 1) collect clips newer than `since`
    local newClips = {}
    local seen     = {}
    for _, clip in pairs(allClips) do
        if clip.ts > since then
            newClips[#newClips+1] = clip
            seen[clip.id]         = true
        end
    end

    -- 2) cap to the latest 100
    if #newClips > 100 then
        table.sort(newClips, function(a, b) return (a.ts or 0) < (b.ts or 0) end)
        local capped = {}
        local capSeen = {}
        for i = #newClips - 99, #newClips do
            local c = newClips[i]
            capped[#capped+1] = c
            capSeen[c.id]     = true
        end
        newClips, seen = capped, capSeen
    end

    -- 3) merge back any clips ≥ since that the receiver doesn't already have
    if existing then
        local fromTs      = existing.fromTs or since
        local existingMap = existing.clips or existing

        for id, clip in pairs(allClips) do
            if clip.ts >= fromTs
                    and not seen[id]
                    and not existingMap[id]
            then
                newClips[#newClips+1] = clip
                seen[id]             = true
            end
        end
    end

    return newClips
end

-- Players who opted out of Speed Clips (populated via Blacklist events)
ns.SpeedClipsOptedOut = ns.SpeedClipsOptedOut or {}

ns.AddNewDeathClips = function(newClips)
    local existingClips = ns.GetLiveDeathClips()
    for _, clip in ipairs(newClips) do
        -- Skip ALIVE clips below level 10 – they should not be recorded at all
        if clip.deathCause == "ALIVE" and (clip.level or 0) < 10 then
            -- intentionally skipped
        elseif not ns.SpeedClipsOptedOut[clip.characterName] then
            if clip.id then
                clip.playedTime = clip.playedTime or nil  -- Initialize playedTime to nil if not set
                clip.getPlayedTry = 0
                existingClips[clip.id] = clip
                
                -- Add to queue if needed (deduplicated)
                if not clip.playedTime and clip.deathCause ~= "ALIVE" then
                    ns.AddClipToQueue(clip)
                end
            end
        end
    end
end

ns.RemoveDeathClip = function(clipID)
    local existingClips = ns.GetLiveDeathClips()
    existingClips[clipID] = nil
end

-- Archive for quick restoration
ns.SpeedClipsArchive = ns.SpeedClipsArchive or {}

ns.RemovePlayerFromSpeedClips = function(playerName)
    local existingClips = ns.GetLiveDeathClips()
    local removedCount = 0
    local archivedClips = {}
    
    -- Archive and remove all clips for this player
    for clipID, clip in pairs(existingClips) do
        if clip.characterName == playerName then
            archivedClips[clipID] = clip -- Archive before removing
            existingClips[clipID] = nil
            removedCount = removedCount + 1
        end
    end
    
    -- Store in archive for quick restoration
    if removedCount > 0 then
        ns.SpeedClipsArchive[playerName] = archivedClips
    end
    
    -- Also remove from queue if present
    if queue[playerName] then
        queue[playerName] = nil
    end
    
    -- Fire event to update UI
    if removedCount > 0 then
        ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
    end
    
    ns.SpeedClipsOptedOut[playerName] = true -- remember preference
    
    return removedCount
end

ns.RestorePlayerSpeedClips = function(playerName)
    local existingClips = ns.GetLiveDeathClips()
    local archivedClips = ns.SpeedClipsArchive[playerName]
    local restoredCount = 0
    
    if archivedClips then
        -- Restore clips from archive
        for clipID, clip in pairs(archivedClips) do
            existingClips[clipID] = clip
            restoredCount = restoredCount + 1
        end
        
        
        -- Clear archive
        ns.SpeedClipsArchive[playerName] = nil
    end
    
    -- Clear opt-out status
    ns.SpeedClipsOptedOut[playerName] = nil
    
    -- Fire event to update UI immediately
    if restoredCount > 0 then
        ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
    end
    
    return restoredCount
end

ns.GetCompletedDeathClips = function()
    local completedClips = {}
    for _, clip in pairs(ns.GetLiveDeathClips()) do
        if clip.completed then
            table.insert(completedClips, clip)
        end
    end
    return completedClips
end

ns.GetPlayedDeathClips = function()
    local playedClips = {}
    -- Realm-filtered loop  ↓
    for _, clip in pairs(ns.FilterClipsThisRealm(ns.GetLiveDeathClips())) do
        if clip.playedTime then
            table.insert(playedClips, clip)
        end
    end
    return playedClips
end

ns.GetNoPlayedDeathClips = function()
    local clips = {}
    -- Realm-filtered loop  ↓
    for _, clip in pairs(ns.FilterClipsThisRealm(ns.GetLiveDeathClips())) do
        if not clip.playedTime then
            table.insert(clips, clip)
        end
    end
    return clips
end


-- Cache for level statistics to avoid recalculating
local levelStatsCache = {}
local lastCacheUpdate = 0
local CACHE_DURATION = 5 -- seconds

-- Helper function to get or calculate level statistics
local function GetLevelStats(level)
    local now = GetServerTime()

    -- Check if cache is valid and has data for this level
    if now - lastCacheUpdate < CACHE_DURATION and levelStatsCache[level] then
        return levelStatsCache[level]
    end

    -- Recalculate if cache is expired or missing this level
    local relevant = {}
    for _, clip in pairs(ns.FilterClipsThisRealm(ns.GetLiveDeathClips())) do
        if tonumber(clip.level) == level and clip.playedTime then
            relevant[#relevant + 1] = tonumber(clip.playedTime)
        end
    end

    if #relevant < 5 then
        levelStatsCache[level] = nil
        return nil
    end

    table.sort(relevant)
    local count = #relevant

    -- индексы перцентилей
    local idx10 = math.max(1, math.ceil(count * 0.10))
    local idx25 = math.max(1, math.ceil(count * 0.25))
    local idx50 = math.max(1, math.ceil(count * 0.50))
    local idx75 = math.max(1, math.ceil(count * 0.75))
    local idx90 = math.max(1, math.ceil(count * 0.90))

    local stats = {
        count = count,
        sorted = relevant,
        legend_boundary = relevant[idx10],   -- p10
        fast_boundary = relevant[idx25],     -- p25
        medium_boundary = relevant[idx50],   -- p50
        slow_boundary = relevant[idx75],     -- p75
        wave_boundary = relevant[idx90],     -- p90
        legend_first = relevant[1],
        fast_first = relevant[idx10 + 1] or relevant[count],
        medium_first = relevant[idx25 + 1] or relevant[count],
        slow_first = relevant[idx50 + 1] or relevant[count],
        wave_first = relevant[idx75 + 1] or relevant[count]
    }

    levelStatsCache[level] = stats
    lastCacheUpdate = now
    return stats
end

-- Optimized GetPlayedTimeColor function
ns.GetPlayedTimeColor = function(seconds, level)
    if not seconds or not level then
        return 1,1,1,
        nil,nil,nil,       -- median, p25, p75
        nil,nil,           -- rank, count
        nil,nil,nil,nil,nil, -- boundaries
        nil,nil,nil,nil,nil  -- firsts
    end

    seconds = tonumber(seconds)
    level = tonumber(level)

    local stats = GetLevelStats(level)
    if not stats then
        return 1,1,1,
        nil,nil,nil,
        nil,nil,
        nil,nil,nil,nil,nil,
        nil,nil,nil,nil,nil
    end

    -- цвет игрока по границам
    local r,g,b
    if seconds <= stats.legend_boundary then
        r,g,b = 0.0, 1.0, 0.0
    elseif seconds <= stats.fast_boundary then
        r,g,b = 1.0, 1.0, 0.0
    elseif seconds <= stats.medium_boundary then
        r,g,b = 1.0, 1.0, 1.0
    elseif seconds <= stats.slow_boundary then
        r,g,b = 1.0, 0.5, 0.0
    else
        r,g,b = 1.0, 0.0, 0.0
    end

    -- ранг
    local rank = stats.count + 1
    for i, v in ipairs(stats.sorted) do
        if seconds <= v then
            rank = i
            break
        end
    end

    -- вернуть 18 значений
    return r, g, b,
    stats.medium_boundary, stats.fast_boundary, stats.slow_boundary, -- p50, p25, p75
    rank, stats.count,
    stats.legend_boundary, stats.fast_boundary, stats.medium_boundary, stats.slow_boundary, stats.wave_boundary,
    stats.legend_first, stats.fast_first, stats.medium_first, stats.slow_first, stats.wave_first
end

-- Clear cache when clips change
ns.AuctionHouseAPI:RegisterEvent(ns.EV_DEATH_CLIPS_CHANGED, function()
    levelStatsCache = {}
    lastCacheUpdate = 0
end)

ns.AuctionHouseAPI:RegisterEvent(ns.EV_PLAYED_TIME_UPDATED, function()
    levelStatsCache = {}
    lastCacheUpdate = 0
end)






-- Create the frame to listen for addon messages
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix == "ASMSG_HARDCORE_DEATH" then
            -- 1) Parse incoming message parts
            local parts      = {}
            for part in message:gmatch("([^:]+)") do
                table.insert(parts, part)
            end

            local name       = parts[1]
            local raceId     = tonumber(parts[2])
            local classId    = tonumber(parts[4])
            local level      = tonumber(parts[5])
            local rawZone    = parts[6] or ""
            local causeCode  = tonumber(parts[7]) or 0
            local rawMobName = parts[8] or ""
            local rawMobLv   = tonumber(parts[9]) or 0

            -- 2) Normalize zone
            local zoneStr = rawZone:gsub("\n", " ")
            if zoneStr == "" then zoneStr = "Неизвестно" end

            -- 3) Decide the plain cause text
            local causeText = (causeCode == 7 and rawMobName ~= "")
                    and rawMobName
                    or (ns.DeathCauseByID[causeCode] or "Неизвестно")

            -- 4) Build the unique clip ID
            local factionStr = (races[raceId] and races[raceId].faction) or "Unknown"

            -- 5) Assemble the clip with only the raw fields
            local clip = {
                ts            = GetServerTime(),
                characterName = name,
                race          = (races[raceId] and races[raceId].name) or "Неизвестно",
                faction       = factionStr,
                class         = classes[classId] or "Неизвестно",
                level         = level,
                where         = zoneStr,
                causeCode     = causeCode,     -- numeric cause ID
                deathCause    = causeText,     -- raw text
                mobLevel      = rawMobLv,      -- raw number
                playedTime    = nil,           -- will be filled later
                getPlayedTry  = 0,
                realm         = ns.CURRENT_REALM,
            }

            clip.id = ns.GenerateClipID(clip, false)

            -- 6) Deduplicate
            if not clip.id or ns.GetLiveDeathClips()[clip.id] then
                return
            end

            -- Add the completed clip to the queue (for both death and completed clips)
            ns.AddClipToQueue(clip)

            -- 7) Check opt-out preference for current player
            local currentPlayer = UnitName("player")
            if name == currentPlayer then
                local participateInSpeedClips = ns.PlayerPrefs:Get("participateInSpeedClips")
                if participateInSpeedClips == false then
                    -- Player opted out, don't add their clip
                    return
                end
            end
            
            -- 8) Merge, notify UI and broadcast
            ns.AddNewDeathClips({ clip })
            ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
            ns.AuctionHouse:BroadcastDeathClipAdded(clip)


    elseif prefix == "ASMSG_HARDCORE_COMPLETE" then
            -- parse the incoming message
            local parts     = { strsplit(":", message) }
            local name      = parts[1]
            local raceId    = tonumber(parts[2])
            local genderId  = tonumber(parts[3])
            local classId   = tonumber(parts[4])

            -- default/fallback values
            local level        = 80                                  -- no level in COMPLETE msg
            local zoneStr      = "Неизвестно"
            local causeCode    = 0                                   -- non-creature
            local deathCause   = ns.DeathCauseByID[causeCode] or "Неизвестно"
            local mobLevel     = 0

            -- build the unique clip ID
            local factionStr = (races[raceId] and races[raceId].faction) or "Unknown"
            zoneStr = zoneStr:gsub("\n", " ")

            -- assemble the clip with the new unified fields
            local clip = {
                ts            = GetServerTime(),
                characterName = name,
                race          = (races[raceId] and races[raceId].name) or "Неизвестно",
                faction       = factionStr,
                class         = classes[classId] or "Неизвестно",
                level         = level,
                where         = zoneStr,
                causeCode     = causeCode,     -- NEW: numeric cause for UI logic
                deathCause    = deathCause,    -- NEW: plain text for UI logic
                mobLevel      = mobLevel,      -- NEW: plain number for UI logic
                completed     = true,
                playedTime    = nil,           -- will be populated later
                realm         = ns.CURRENT_REALM,       -- human-readable realm
            }

            clip.id = ns.GenerateClipID(clip, true)

            -- dedupe guard
            if not clip.id or ns.GetLiveDeathClips()[clip.id] then
                return
            end

            -- Add the completed clip to the queue (for both death and completed clips)
            ns.AddClipToQueue(clip)

            -- Check opt-out preference for current player
            local currentPlayer = UnitName("player")
            if name == currentPlayer then
                local participateInSpeedClips = ns.PlayerPrefs:Get("participateInSpeedClips")
                if participateInSpeedClips == false then
                    -- Player opted out, don't add their clip
                    return
                end
            end
            
            -- If no duplicate, add the clip
            --            print("Adding new clip for: " .. name .. " with ID: " .. clip.id)

            ns.AddNewDeathClips({ clip })
            ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
        end

    end
end)


--ns.GameEventHandler:On("PLAYER_DEAD", function()
--    if ns.CharacterPrefs:Get("diedAtLeastOnce") then
--        return
--    end
--    ns.CharacterPrefs:Set("diedAtLeastOnce", true)
--
--    local ts = GetServerTime()
--    local me = UnitName("player")
--    local twitchName = ns.GetTwitchName(me)
--    local clipId = string.format("%d-%s", ts, me)
--    local raceId = select(3, UnitRace("player"))
--    local classId = select(3, UnitClass("player"))
--    local mapId = C_Map.GetBestMapForUnit("player")
--    local mapInfo = C_Map.GetMapInfo(mapId)
--    local zone = mapInfo and mapInfo.name or nil
--    local level = UnitLevel("player")
--    local clip = {
--        id = clipId,
--        ts = ts,
--        streamer = twitchName,
--        characterName = me,
--        race = ns.id_to_race[raceId],
--        class = ns.id_to_class[classId],
--        level = level,
--        where = zone,
--        mapId = mapId,
--    }
--
--    ns.AddNewDeathClips({clip})
--    ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
--    ns.AuctionHouse:BroadcastDeathClipAdded(clip)
--    C_Timer:After(2, function()
--        ns.AuctionHouse:BroadcastDeathClipAdded(clip)
--    end)
--
--end)


--===== Hardcore Death → Ladder (with '|' splitting) =====--
local f = CreateFrame("Frame", "HardcoreDeathTimerReporter")
local listening = false
local nextUpdateDeadline = nil
local ladderBuffer = {}

-- Register necessary events
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_LOGOUT")  -- Listen for logout event

-- Function to save logout data
local function saveLogoutData()
    -- Ensure saved variables table exists (can be wiped by /atheneclear)
    AuctionHouseDBSaved = AuctionHouseDBSaved or {}

    local now = time()
    -- Simply store the current time as the last logout time
    AuctionHouseDBSaved.lastLogoutTime = now  -- Store the last logout time (current time)
    AuctionHouseDBSaved.nextUpdateDeadline = nextUpdateDeadline  -- Store the next update deadline
    --print("lastLogoutTime and nextUpdateDeadline saved during logout: ", AuctionHouseDBSaved.lastLogoutTime, AuctionHouseDBSaved.nextUpdateDeadline)
end

-- Event handler for all the registered events
f:SetScript("OnEvent", function(self, event, prefix, msg)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Ensure saved variables table exists in case it was cleared while addon was already loaded
        AuctionHouseDBSaved = AuctionHouseDBSaved or {}

        local now = time()
        listening = false -- Ensure listening is off until timer fires

        -- Load relevant saved data
        local savedLogoutTime = AuctionHouseDBSaved and AuctionHouseDBSaved.lastLogoutTime
        local savedDeadline = AuctionHouseDBSaved and AuctionHouseDBSaved.nextUpdateDeadline

        -- Variable to hold the message we want to print later
        local deadlineStatusMessage = ""

        -- *** CORE LOGIC CHANGE START ***
        -- Check if the last logout was within 5 minutes
        if savedLogoutTime and (now - savedLogoutTime) < 300 then
            -- Yes, recent login: Use the deadline saved in the DB from the previous session
            nextUpdateDeadline = savedDeadline
            if nextUpdateDeadline then
                local remaining = nextUpdateDeadline - now
                if remaining < 0 then
                    local passedBy = math.abs(remaining)
                    local cyclesMissed = math.floor(passedBy / 600) + 1
                    local predictedNext = nextUpdateDeadline + (cyclesMissed * 600)
                    local nextIn = predictedNext - now

                    nextUpdateDeadline = predictedNext
                    AuctionHouseDBSaved.nextUpdateDeadline = predictedNext


                    --deadlineStatusMessage = string.format("Saved deadline passed %s ago. Predicting next ladder event in ~%s.", SecondsToTime(passedBy), SecondsToTime(nextIn))
                else
                    -- Store the message instead of printing
--                    deadlineStatusMessage = string.format("Recent login (<300s): Using saved deadline. Next update in: %s", SecondsToTime(remaining))
                end
            else
                -- Store the message instead of printing
                deadlineStatusMessage = "Recent login (<300s): No deadline was saved in DB. Waiting for ladder event."
                savedLogoutTime = nil
                nextUpdateDeadline = nil -- Ensure it's nil if nothing was saved
            end
        else
            -- No, login was > 300s ago OR no logout time saved: Do NOT use the saved deadline.
            if savedLogoutTime then
                -- Store the message instead of printing
                --deadlineStatusMessage = string.format("Login >300s ago (%s). Ignoring saved deadline. Waiting for ladder event.", SecondsToTime(now - savedLogoutTime))
                savedLogoutTime = nil
            else
                -- Store the message instead of printing
--                deadlineStatusMessage = "No previous logout time. Ignoring saved deadline. Waiting for ladder event."
            end
            nextUpdateDeadline = nil -- Start fresh, wait for ladder event to set it
        end
        -- *** CORE LOGIC CHANGE END ***

        -- *** ADDED DELAY FOR PRINTING ***
        -- Schedule the stored message to be printed after 9 seconds
        if deadlineStatusMessage ~= "" then
            C_Timer:After(9, function()
                --print(deadlineStatusMessage)
            end)
        end
        -- *** END ADDED DELAY ***

        -- Iterate over completed clips and check if they don't have a playedTime (Keep original code)
        local playedClips = ns.GetNoPlayedDeathClips() -- Make sure 'ns' and the function exist
        for _, clip in ipairs(playedClips) do
            if type(clip) == "table" then
                if not clip.playedTime and clip.characterName then
                    if not clip.getPlayedTry then
                        clip.getPlayedTry = 0
                    end
                    if type(clip.getPlayedTry) == "number" and clip.getPlayedTry < 3 then
                        -- Original queueing logic (ensure 'queue' is defined)
                        ns.AddClipToQueue(clip)
                        -- This print has its own 10s delay, keep disabled to avoid spam
                        -- C_Timer:After(10, function()
                        --     print(clip.characterName .. " added to the queue (no playedTime)")
                        -- end)
                    end
                end
            end
        end

        -- skip auto-refresh on login/reload (Keep original code)
        C_Timer:After(3, function()
            listening = true
        end)

        return -- End PLAYER_ENTERING_WORLD block
    end

    if event == "PLAYER_LOGOUT" then
        -- Save the logout data when the player logs out
        saveLogoutData()
        return
    end

    if not listening then
        return
    end

    -- Handle "ASMSG_HARDCORE_DEATH" event
    if prefix == "ASMSG_HARDCORE_DEATH" then
        local admin = UnitName("player")
        if admin == "Lenkomag" then
            --PlaySoundFile("Sound\\interface\\MapPing.wav")
        end
        ------------------------------------------------------------------
        -- Парсинг сообщения о смерти для составления детального баннера
        ------------------------------------------------------------------
        local parts = {}
        for part in string.gmatch(msg, "([^:]+)") do
            table.insert(parts, part)
        end

        local name       = parts[1]
        if name then
            local raceId     = tonumber(parts[2])
            local _genderId  = tonumber(parts[3]) -- в настоящее время не используется
            local classId    = tonumber(parts[4])
            local level      = tonumber(parts[5])
            local rawZone    = parts[6] or ""
            local causeCode  = tonumber(parts[7]) or 0
            local rawMobName = parts[8] or ""
            local rawMobLv   = tonumber(parts[9]) or 0

            ------------------------------------------------------------------
            -- Цвета для имени (по классу) и расы (по фракции)
            ------------------------------------------------------------------
            local classTag   = classes[classId]
            local cColor     = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag] or { r = 1, g = 1, b = 1 }
            local colouredName = string.format("|cFF%02X%02X%02X%s|r", cColor.r * 255, cColor.g * 255, cColor.b * 255, name)

            local faction    = (races[raceId] and races[raceId].faction) or "Neutral"
            local FACTION_COLOURS = {
                Horde    = "FFFF4040",   -- Красный
                Alliance = "FF1890FF",   -- Синий
                Neutral  = "FFFFD700",   -- Жёлтый
            }
            local raceColourHex = FACTION_COLOURS[faction] or "FFFFFFFF"
            local colouredRace  = string.format("|c%s%s|r", raceColourHex, (races[raceId] and races[raceId].name) or "Неизвестно")

            ------------------------------------------------------------------
            -- Причина смерти и зона
            ------------------------------------------------------------------
            local zoneStr = rawZone:gsub("\n", " ")
            if zoneStr == "" then zoneStr = "Неизвестно" end

            local causeStr
            if causeCode == 7 then
                causeStr = string.format("существом %s %d-го уровня", rawMobName, rawMobLv)
            else
                causeStr = (deathCauses[causeCode] or (ns.DeathCauseByID and ns.DeathCauseByID[causeCode]) or "Неизвестно")
            end

            ------------------------------------------------------------------
            -- Проверяем настройку пользователя (по умолчанию – показывать)
            ------------------------------------------------------------------
            if ns.PlayerPrefs and ns.PlayerPrefs.Get then
                local showPrints = ns.PlayerPrefs:Get("showDeathPrintsInChat")
                if showPrints == false then
                    return -- пользователь отключил сообщения
                end
            end

            ------------------------------------------------------------------
            -- Вывод баннеров в чат
            ------------------------------------------------------------------
            if nextUpdateDeadline then
                local left = nextUpdateDeadline - time()
                if left < 0 then
                    nextUpdateDeadline = nil -- таймер устарел
                else
                    local ts   = date("%H:%M:%S")
                    local grey = "|cFF808080[%s]|r "

                    -- Основной баннер c описанием смерти
                    local banner1 = string.format(
                        grey .. "%s, %s %d-го уровня, был убит %s в зоне \"%s\"",
                        ts, colouredName, colouredRace, level, causeStr, zoneStr
                    )

                    -- Баннер о времени до следующего обновления ладдера
                    local banner2 = string.format(
                        grey .. "Next ladder in |cFFFFFF00%s|r",
                        ts, SecondsToTime(left)
                    )

                    print(banner1)
                    --print(banner2)
                end
            end
        end

        -- Handle "ASMSG_HARDCORE_LADDER_LIST" event
    elseif prefix == "ASMSG_HARDCORE_LADDER_LIST" then
        -- [ Keep all ladder data processing code exactly as provided by user ]
        for block in msg:gmatch("([^|]+)") do
            local id, data = block:match("^(%d+):(.*)")
            if id and data then
                ladderBuffer[id] = (ladderBuffer[id] or "") .. data
                if data:match(";$") then
                    -- Continue
                else
                    local full = ladderBuffer[id]
                    ladderBuffer[id] = nil
                    if full then
                        for entry in full:gmatch("([^;]+)") do
                            local _, n, _, _, _, _, tm_str = entry:match("^(%d+):([^:]+):(%d+):(%d+):(%d+):(%d+):(%d+)$")
                            local tm = tonumber(tm_str)
                            if n and tm and queue and queue[n] then
                                if type(queue[n]) == "table" then
                                    local playerRemoved = false
                                    for _, clip in ipairs(queue[n]) do
                                        if playerRemoved then break end
                                        if type(clip) == "table" then
                                            if clip.completed and clip.playedTime == nil then
                                                clip.playedTime = tm

                                                -- 🔔 Fire event to notify UI
                                                ns.AuctionHouseAPI:FireEvent(ns.EV_PLAYED_TIME_UPDATED, clip.id)

                                                print("|cFF00FF00" .. string.format("[%s] %s's playedTime updated to: %d", date("%H:%M:%S"), n, tm) .. "|r")
                                                queue[n] = nil
                                                clip.getPlayedTry = nil
                                                playerRemoved = true
                                            elseif not clip.completed and clip.playedTime == nil then -- Added nil check based on debug analysis
                                                clip.playedTime = tm

                                                -- 🔔 Fire event to notify UI
                                                ns.AuctionHouseAPI:FireEvent(ns.EV_PLAYED_TIME_UPDATED, clip.id)

                                                print("|cFF00FF00" .. string.format("[%s] %s lasted %s", date("%H:%M:%S"), n, SecondsToTime(tm)) .. "|r")
                                                queue[n] = nil
                                                clip.getPlayedTry = nil
                                                playerRemoved = true
                                                -- else -- Use original state (commented or not)
                                                --    print("Clip not updated due clip completed or playedTime missing")
                                                -- end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end -- End block loop

            -- <<< MINIMAL: only bump once per 10m interval
            -- [ Keep this do...end block EXACTLY as provided by user ]
            do
                local now = time()
                if not nextUpdateDeadline then
                    nextUpdateDeadline = now + 600
                end
                if now >= nextUpdateDeadline then
                    if queue then
                        for name, clips in pairs(queue) do
                            if type(clips) == "table" then
                                local playerMarkedForRemoval = false
                                for i = #clips, 1, -1 do
                                    local clip = clips[i]
                                    if type(clip) == "table" then
                                        -- Check type is number OR nil (to allow init) AND playedTime is nil
                                        if not clip.playedTime and (type(clip.getPlayedTry) == "number" or clip.getPlayedTry == nil) then
                                            if clip.getPlayedTry == nil then clip.getPlayedTry = 0 end -- Init

                                            -- Original code incremented if it was a number
                                            if type(clip.getPlayedTry) == "number" then
                                                clip.getPlayedTry = clip.getPlayedTry + 1
                                                -- DEBUG: print every time getPlayedTry is incremented
                                                --print(string.format("[DEBUG %s] getPlayedTry increment for %s -> %d (clipID=%s)",
                                                --    date("%M:%S"), name or "?", clip.getPlayedTry, clip.id or "nil"))
                                                if clip.getPlayedTry >= 2 then
                                                    print(name .. " getPlayedTry attempt " .. clip.getPlayedTry)
                                                end
                                                if clip.getPlayedTry >= 3 then
                                                    clip.getPlayedTry = "failed"
                                                    -- DEBUG: mark as failed
                                                    print(string.format("[DEBUG %s] getPlayedTry failed (≥3 attempts) for %s (clipID=%s)",
                                                        date("%M:%S"), name or "?", clip.id or "nil"))
                                                    print(name .. " getPlayedTry failed after 3 attempts — removing from queue")
                                                    playerMarkedForRemoval = true
                                                end
                                            end
                                        elseif clip.getPlayedTry == "failed" then
                                            -- If already failed, still mark player for removal based on original logic
                                            playerMarkedForRemoval = true
                                        end
                                    else
                                        table.remove(clips, i) -- remove bad data
                                    end
                                end
                                -- Original removal logic
                                if playerMarkedForRemoval then
                                    queue[name] = nil
                                elseif #clips == 0 then
                                    queue[name] = nil
                                end
                            else
                                queue[name] = nil -- Remove bad player entry
                            end
                        end -- End queue loop
                    end -- End if queue
                    -- This reset happens *only* when the deadline check passes
                    nextUpdateDeadline = now + 600
                    --print("Next Update Timer, updated to : " .. SecondsToTime(nextUpdateDeadline - time()))
                end -- End deadline check
            end -- End do block

            -- MINIMAL CHANGE: Remove the conflicting unconditional reset below.
            -- This ensures the deadline check in the do...end block uses the
            -- value set by the *last successful check*, allowing the 10-minute
            -- interval to function correctly *relative to the check itself*.
            -- nextUpdateDeadline = time() + 600  -- REMOVED

        end -- End elseif ASMSG_HARDCORE_LADDER_LIST
    end
    ns.nextUpdateDeadline = nextUpdateDeadline
end)
