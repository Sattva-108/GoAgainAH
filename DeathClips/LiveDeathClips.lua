local _, ns = ...

------------------------------------------------------------------------
-- >>> REALM SUPPORT
------------------------------------------------------------------------
local fullName = GetRealmName() or ""
ns.CURRENT_REALM_CODE = ns.RealmFullNameToID[fullName] or 0

print(("Current realm: %q → code %d"):format(fullName, ns.CURRENT_REALM_CODE))



-- Filter helper ----------------------------------------------
function ns.FilterClipsThisRealm(pool)
    local filtered = {}
    for _, clip in pairs(pool) do
        if clip.realmCode == ns.CURRENT_REALM_CODE then
            table.insert(filtered, clip)
        end
    end
    return filtered
end

------------------------------------------------------------------------


-- Define the global queue table to track both completed and death event characters
local queue = {}

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
    [24] = { name = "Озарён. дреней", faction = "Alliance" },
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

-- Paste this complete function into LiveDeathClips.lua, replacing the existing ns.GetNewDeathClips

ns.GetNewDeathClips = function(since, existing)
    local allClips = ns.GetLiveDeathClips()

    -- Counters for debugging
    local totalClips        = 0
    local tsPassCount       = 0
    local tsFailCount       = 0
    local afterCapCount     = 0
    local mergeBackCount    = 0
    local excludeSeenCount  = 0
    local excludeExistCount = 0
    local excludeTsCount    = 0

    -- Count total
    for _ in pairs(allClips) do totalClips = totalClips + 1 end
    print(("|cffffff00[Debug] Total live clips: %d|r"):format(totalClips))

    -- 1) “since” filter
    local newClips = {}
    local seen     = {}
    for id, clip in pairs(allClips) do
        if clip.ts > since then
            tsPassCount = tsPassCount + 1
            newClips[#newClips+1] = clip
            seen[id] = true
        else
            tsFailCount = tsFailCount + 1
        end
    end
    print(("|cffffff00[Debug] After ts> %d filter: %d passed, %d failed|r")
            :format(since, tsPassCount, tsFailCount))

    -- 2) cap to latest 100
    if #newClips > 100 then
        table.sort(newClips, function(a,b) return (a.ts or 0) < (b.ts or 0) end)
        local capped = {}
        local newSeen = {}
        for i = #newClips-99, #newClips do
            local c = newClips[i]
            capped[#capped+1] = c
            newSeen[c.id] = true
        end
        newClips = capped
        seen = newSeen
    end
    afterCapCount = #newClips
    print(("|cffffff00[Debug] After capping to 100: %d clips|r"):format(afterCapCount))

    -- 3) merge back
    if existing then
        local fromTs       = existing.fromTs or since
        local existingMap  = existing.clips or existing
        local beforeMerge  = #newClips

        for id, clip in pairs(allClips) do
            if clip.ts < fromTs then
                excludeTsCount = excludeTsCount + 1
            elseif seen[id] then
                excludeSeenCount = excludeSeenCount + 1
            elseif existingMap[id] then
                excludeExistCount = excludeExistCount + 1
            else
                -- this will be merged back
                newClips[#newClips+1] = clip
                seen[id] = true
                mergeBackCount = mergeBackCount + 1
            end
        end

        print(("|cffffff00[Debug] Merged back: %d|r"):format(mergeBackCount))
        print(("|cffffff00[Debug] Excluded by ts<fromTs: %d|r"):format(excludeTsCount))
        print(("|cffffff00[Debug] Excluded by seen (cap): %d|r"):format(excludeSeenCount))
        print(("|cffffff00[Debug] Excluded by existing map: %d|r"):format(excludeExistCount))
    end

    return newClips
end


ns.AddNewDeathClips = function(newClips)
    local existingClips = ns.GetLiveDeathClips()
    for _, clip in ipairs(newClips) do
        -- Ensure that the clip has a valid ID and playedTime before attempting to add it
        if clip.id then
            clip.playedTime = clip.playedTime or nil  -- Initialize playedTime to nil if not set
            clip.getPlayedTry = 0
            existingClips[clip.id] = clip
        else
            --print("Error: Clip ID is nil for character:", clip.characterName)
        end
    end
end

ns.RemoveDeathClip = function(clipID)
    local existingClips = ns.GetLiveDeathClips()
    existingClips[clipID] = nil
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

-- Returns R, G, B, median, lower, upper based on playedTime relative to level median
ns.GetPlayedTimeColor = function(seconds, level)
    if not seconds or not level then
        return 1, 1, 1, nil, nil, nil
    end

    seconds = tonumber(seconds)
    level   = tonumber(level)

    local relevant = {}
    -- Realm-filtered loop  ↓
    for _, clip in pairs(ns.FilterClipsThisRealm(ns.GetLiveDeathClips())) do
        if tonumber(clip.level) == level and clip.playedTime then
            table.insert(relevant, tonumber(clip.playedTime))
        end
    end

    if #relevant < 5 then
        return 1, 1, 1, nil, nil, nil
    end

    table.sort(relevant)
    local mid = math.floor(#relevant / 2)
    local median = (#relevant % 2 == 1) and relevant[mid + 1]
            or (relevant[mid] + relevant[mid + 1]) / 2

    local lower = median * 0.7
    local upper = median * 1.3

    if seconds <= lower then
        return 0.25, 1.0, 0.25, median, lower, upper -- Green
    elseif seconds <= median then
        return 1.0, 1.0, 0.3, median, lower, upper -- Yellow
    elseif seconds <= upper then
        return 1.0, 1.0, 1.0, median, lower, upper -- White
    else
        return 1.0, 0.25, 0.25, median, lower, upper -- Red
    end
end



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
            local clipID     = string.format(
                    "%s-%d-%s-%s-%s",
                    name, level, zoneStr, factionStr, causeText
            )

            -- 5) Assemble the clip with only the raw fields
            local clip = {
                id            = clipID,
                ts            = GetServerTime(),
                streamer      = ns.GetTwitchName(name) or name,
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
                realmCode     = ns.CURRENT_REALM_CODE,
                realm         = ns.CURRENT_REALM,
            }

            -- 6) Deduplicate
            if not clip.id or ns.GetLiveDeathClips()[clip.id] then
                return
            end

            -- Add the completed clip to the queue (for both death and completed clips)
            -- Add the played clip to the queue (for both death and played clips)
            queue[name] = queue[name] or {}
            clip.playedTime = clip.playedTime or nil  -- Initialize playedTime if not set
            clip.getPlayedTry = 0
            table.insert(queue[name], clip)

            -- 7) Merge, notify UI and broadcast
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
            local clipID = string.format(
                    "%s-%d-%s-%s-%s",
                    name,
                    level,
                    zoneStr,
                    factionStr,
                    deathCause
            )

            -- assemble the clip with the new unified fields
            local clip = {
                id            = clipID,
                ts            = GetServerTime(),
                streamer      = ns.GetTwitchName(name) or name,
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
                realmCode     = ns.CURRENT_REALM_CODE,  -- filter by numeric realm
                realm         = ns.CURRENT_REALM,       -- human-readable realm
            }

            -- dedupe guard
            if not clip.id or ns.GetLiveDeathClips()[clip.id] then
                return
            end

            -- Add the completed clip to the queue (for both death and completed clips)
            -- Add the played clip to the queue (for both death and played clips)
            queue[name]      = queue[name] or {}
            clip.playedTime = clip.playedTime or nil  -- Initialize playedTime if not set
            clip.getPlayedTry = 0
            table.insert(queue[name], clip)

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
    local now = time()
    -- Simply store the current time as the last logout time
    AuctionHouseDBSaved.lastLogoutTime = now  -- Store the last logout time (current time)
    AuctionHouseDBSaved.nextUpdateDeadline = nextUpdateDeadline  -- Store the next update deadline
    print("lastLogoutTime and nextUpdateDeadline saved during logout: ", AuctionHouseDBSaved.lastLogoutTime, AuctionHouseDBSaved.nextUpdateDeadline)
end

-- Event handler for all the registered events
f:SetScript("OnEvent", function(self, event, prefix, msg)
    if event == "PLAYER_ENTERING_WORLD" then
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


                    deadlineStatusMessage = string.format("Saved deadline passed %s ago. Predicting next ladder event in ~%s.", SecondsToTime(passedBy), SecondsToTime(nextIn))
                else
                    -- Store the message instead of printing
                    deadlineStatusMessage = string.format("Recent login (<300s): Using saved deadline. Next update in: %s", SecondsToTime(remaining))
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
                deadlineStatusMessage = string.format("Login >300s ago (%s). Ignoring saved deadline. Waiting for ladder event.", SecondsToTime(now - savedLogoutTime))
                savedLogoutTime = nil
            else
                -- Store the message instead of printing
                deadlineStatusMessage = "No previous logout time. Ignoring saved deadline. Waiting for ladder event."
            end
            nextUpdateDeadline = nil -- Start fresh, wait for ladder event to set it
        end
        -- *** CORE LOGIC CHANGE END ***

        -- *** ADDED DELAY FOR PRINTING ***
        -- Schedule the stored message to be printed after 9 seconds
        if deadlineStatusMessage ~= "" then
            C_Timer:After(9, function()
                print(deadlineStatusMessage)
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
                        queue[clip.characterName] = queue[clip.characterName] or {}
                        -- Prevent adding duplicates if necessary (simple reference check shown)
                        local found = false
                        for _, existingClip in ipairs(queue[clip.characterName]) do
                            if existingClip == clip then found = true break end
                        end
                        if not found then
                            table.insert(queue[clip.characterName], clip)
                            -- This print has its own 10s delay, leave it as is
                            C_Timer:After(10, function()
                                --print(clip.characterName .. " added to the queue (no playedTime)")
                            end)
                        end
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
            PlaySoundFile("Sound\\interface\\MapPing.wav")
        end
        local name = msg:match("^([^:]+)")
        if name then
            if nextUpdateDeadline then
                local left = nextUpdateDeadline - time()
                if left < 0 then
                    left = 0
                end
                print(("%s died — next ladder in %s"):format(name, SecondsToTime(left)))
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
                                                print(("%s's playedTime updated to: %d"):format(n, tm), "|cFF00FF00" .. ("%s's playedTime updated to: %d"):format(n, tm) .. "|r")
                                                queue[n] = nil
                                                clip.getPlayedTry = nil
                                                playerRemoved = true
                                            elseif not clip.completed and clip.playedTime == nil then -- Added nil check based on debug analysis
                                                clip.playedTime = tm
                                                print("|cFF00FF00" .. ("%s lasted %s"):format(n, SecondsToTime(tm)) .. "|r")
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
                                                if clip.getPlayedTry >= 2 then
                                                    print(name .. " getPlayedTry attempt " .. clip.getPlayedTry)
                                                end
                                                if clip.getPlayedTry >= 3 then
                                                    clip.getPlayedTry = "failed"
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
                    print("Next Update Timer, updated to : " .. SecondsToTime(nextUpdateDeadline - time()))
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

